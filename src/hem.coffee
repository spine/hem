path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
strata    = require('strata')
compilers = require('./compilers')
package   = require('./package')
css       = require('./css')
specs     = require('./specs')
sys       = require('sys')

argv = optimist.usage([
  '  usage: hem COMMAND',
  '    server      start a dynamic development server',
  '    production  start a dynamic development server',
  '    build       serialize application to disk',
  '    watch       build & watch disk for changes'
].join("\n"))
.alias('p', 'port')
.alias('d', 'debug')
.argv

help = ->
  optimist.showHelp()
  process.exit()

class Hem
  @exec: (command, options) ->
    (new @(options)).exec(command)
  
  @include: (props) ->
    @::[key] = value for key, value of props
  
  compilers: compilers
  
  serverOptions:
    paths:        ['./server']
    production:   './.server'
  
  options: 
    slug:         './slug.json'
    serverSlug:   './serverSlug.json'
    css:          './css'
    libs:         []
    public:       './public'
    paths:        ['./app']
    dependencies: []
    port:         process.env.PORT or argv.port or 9294
    cssPath:      '/application.css'
    jsPath:       '/application.js'

    test:         './test'
    testPublic:   './test/public'
    testPath:     '/test'
    specs:        './test/specs'
    specsPath:    '/test/specs.js'

  isProdution:    false
  
  constructor: (options = {}) ->
    @options[key] = value for key, value of options    
    @options[key] = value for key, value of @readSlug()
    
    @serverOptions[key] = value for key, value of @readSlug(@options.serverSlug)
    
    @app = new strata.Builder
    @router = new strata.Router
  
  production: ->
    @isProduction = true
    @server.apply(this, arguments)
  
  server: ->
    @app.use(strata.contentLength)
    
    @router.get(@options.cssPath, @cssPackage().createServer())
    @router.get(@options.jsPath, @hemPackage().createServer())
    
    if path.existsSync(@options.specs)
      @router.get(@options.specsPath, @specsPackage().createServer())
    
    if path.existsSync(@options.testPublic)
      @app.map @options.testPath, (app) =>
        app.use(strata.file, @options.testPublic, ['index.html', 'index.htm'])
    
    if path.existsSync(@options.public)
      @app.use(strata.file, @options.public, ['index.html', 'index.htm'])
    
    @app.run(@router)
    
    if process.env.PRODUCTION or (process.env.ENVIRONMENT is 'production') or @isProduction
      @server = require(path.join(process.cwd(), @serverOptions.production))
      if @server.initOnce
        @server.initOnce(@app)
      if @server.router
        @app.run(@server.router)
    else if @serverOptions.paths.length > 0 and path.existsSync(@serverOptions.paths[0])
      @serverWatch()
      if @server and @server.router
        @app.run (env, callback) =>
          if @server.router
            @server.router.call(env, callback)
          else
            strata.utils.notFound(env, callback)

    strata.run(@app, port: @options.port)
    
  build: ->
    source = @hemPackage().compile(not argv.debug)
    fs.writeFileSync(path.join(@options.public, @options.jsPath), source)
    
    source = @cssPackage().compile()
    fs.writeFileSync(path.join(@options.public, @options.cssPath), source)

    if @serverOptions.paths.length > 0 and path.existsSync(@serverOptions.paths[0])
      console.log('You might need server code which needs to be compiled to "./.server" use "cake build""')
    
  clearCacheForDir: (dir) ->
    for file in fs.readdirSync(dir)
      if file is '.' or file is '..'
        continue
      p = path.join(dir, file)
      stat = fs.statSync(p)
      if stat.isDirectory()
        @clearCacheForDir(p)
      else
        try
          key = require.resolve(p)
          delete require.cache[key]
        catch e
          # Ignore probably a .DS_Store file
  
  serverBuild: (first) ->
    for dir in (path.join(process.cwd(), lib) for lib in @serverOptions.paths)
      @clearCacheForDir(dir)
    try
      @server = require(path.resolve(process.cwd(), @serverOptions.paths[0]))
      if @server.initOnce and first
        @server.initOnce(@app)
    catch e
      sys.puts(e.message)
      if e.stack
        sys.puts(e.stack)
        
  
  watch: ->
    @build() 
    for dir in (path.dirname(lib) for lib in @options.libs).concat @options.css, @options.paths
      continue unless path.existsSync(dir)
      require('watch').watchTree dir, (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          console.log "#{file} changed.  Rebuilding."
          @build()
  
  serverWatch: ->
    @serverBuild(true)
    for dir in (path.resolve(process.cwd(), lib) for lib in @serverOptions.paths)
      continue unless path.existsSync(dir)
      require('watch').watchTree dir, (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          console.log "#{file} changed.  Rebuilding Server."
          @serverBuild(false)

  exec: (command = argv._[0]) ->
    return help() unless @[command]
    @[command]()
    switch command
      when 'build'  then console.log 'Built application'
      when 'watch'  then console.log 'Watching application'

  # Private
    
  readSlug: (slug = @options.slug) -> 
    return {} unless slug and path.existsSync(slug)
    JSON.parse(fs.readFileSync(slug, 'utf-8'))
  
  serverPackage: ->
    package.createPackage(
      @serverOptions
    )
  
  cssPackage: ->
    css.createPackage(@options.css)

  hemPackage: ->
    package.createPackage(
      dependencies: @options.dependencies
      paths: @options.paths
      libs: @options.libs
    )
    
  specsPackage: ->
    specs.createPackage(@options.specs)

module.exports = Hem