path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
strata    = require('strata')
compilers = require('./compilers')
package   = require('./package')
css       = require('./css')
specs     = require('./specs')
if /^v0\.[012]/.test(process.version)
  sys        = require("sys")
else
  sys        = require("util")
EventEmitter = require('events').EventEmitter
cluster = null
try
  cluster = require('cluster')
  numCPUs = require('os').cpus().length
catch e

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

class Hem extends EventEmitter
  @exec: (command, options) ->
    (new @(options)).exec(command)
  
  @include: (props) ->
    @::[key] = value for key, value of props
  
  compilers: compilers
  
  serverOptions:
    paths:        ['./server']
  
  options: 
    slug:         './slug.json'
    serverSlug:   './serverSlug.json'
    css:          './css'
    libs:         []
    public:       './public'
    paths:        ['./app']
    dependencies: []
    port:         process.env.PORT or argv.port or 9294
    host:         process.env.HOST or argv.host or '0.0.0.0'
    cssPath:      '/application.css'
    jsPath:       '/application.js'

    test:         './test'
    testPublic:   './test/public'
    testPath:     '/test'
    specs:        './test/specs'
    specsPath:    '/test/specs.js'

  isProdution:    false
  newRouter:      false
  
  constructor: (options = {}) ->
    @options[key] = value for key, value of options    
    @options[key] = value for key, value of @readSlug()
    
    @serverOptions[key] = value for key, value of @readSlug(@options.serverSlug)
    
    @app = new strata.Builder
  
  production: ->
    @isProduction = true
    
    if cluster
      if cluster.isMaster
        console.log 'starting up master server... minimizing files...'
      else
        console.log "starting up worker #{process.pid}..."
    else
      console.log 'starting up server... minimizing files...'
    @server.apply(this, arguments)
  
  doMapping: (app) ->
    app.use (app) =>
      if not @serverApp
        @serverApp = app
        @server.router.run(@serverApp)
      return (env, callback) =>
        if @server?.router
          try
            @server.router.call(env, callback)
          catch e
            callback(500, {}, e.message)
            sys.puts(e.message)
            if e.stack
              sys.puts(e.stack)
        else
          @serverApp(env, callback)
  
  server: ->
    @app.use(strata.contentLength)
    
    @isProduction or= process.env.PRODUCTION or (process.env.ENVIRONMENT is 'production')
    if @serverOptions.paths.length > 0 and path.existsSync(@serverOptions.paths[0])
      if @isProduction
        @server = require(path.join(process.cwd(), @serverOptions.paths[0]))
      else
        @serverWatch()

    if @server and @server.initOnce
      @server.initOnce(@app)
    if @server and @server.preInitOnce
      @server.preInitOnce(@app, this)

    if not @isProduction
      @app.map @options.cssPath, (app) =>
        app.use @cssPackage().createServer, @options.cssPath
      @app.map @options.jsPath, (app) =>
        app.use @hemPackage().createServer, @options.jsPath
    else
      if (not cluster) or (cluster.isMaster)
        @build()
        console.log 'Built minified files'

    mapped = false
    if path.existsSync(@options.specs)
      @app.map @options.specsPath, (app) =>
        app.use @specsPackage().createServer, @options.specsPath

    if path.existsSync(@options.testPublic)
      @app.map @options.testPath, (app) =>
        app.use(strata.file, @options.testPublic, ['index.html', 'index.htm'])

    if path.existsSync(@options.public)
      mapped = true
      @app.map '/', (app) =>
        app.use(strata.file, @options.public, ['index.html', 'index.htm'])
        @doMapping(app)

    if not mapped
      @app.map '/', (app) =>
        @doMapping(app)
    
    if @server and @server.postInitOnce
      @server.postInitOnce(@app, this)

    if cluster
      if cluster.isMaster
        # Fork workers.
        console.log "master with #{numCPUs} cpus"
        for i in [1..numCPUs - 1]
          cluster.fork()
        cluster.on 'death', (worker) ->
          console.log "worker #{worker.pid} died"
        strata.run(@app, port: @options.port, host: @options.host)
      else
        # Worker processes have a http server.
        strata.run(@app, port: @options.port, host: @options.host)
        console.log "worker #{process.pid} online"
    else
      strata.run(@app, port: @options.port, host: @options.host)
  
  bustedName: (p, bust) ->
    ext = path.extname(p)
    p + '-' + bust + ext
  
  build: ->
    source = @hemPackage().compile(not argv.debug)
    fs.writeFileSync(path.join(@options.public, @options.jsPath), source)
    bustedJsPath = @bustedName(@options.jsPath, @hemPackage().cacheBust)
    fs.writeFileSync(path.join(@options.public, bustedJsPath), source)
    
    source = @cssPackage().compile()
    fs.writeFileSync(path.join(@options.public, @options.cssPath), source)
    bustedCssPath = @bustedName(@options.cssPath, @cssPackage().cacheBust)
    fs.writeFileSync(path.join(@options.public, bustedCssPath), source)
    @emit('bustedPaths', {"js": bustedJsPath, "css": bustedCssPath, "path": @options.public})
    console.log "Busted CSS written to #{bustedCssPath} in #{@options.public}"
    console.log "Busted JS written to #{bustedJsPath}"
  
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
  
  serverBuild: ->
    for dir in (path.join(process.cwd(), lib) for lib in @serverOptions.paths)
      @clearCacheForDir(dir)
    try
      @server = require(path.resolve(process.cwd(), @serverOptions.paths[0]))
    catch e
      sys.puts(e.message)
      if e.stack
        sys.puts(e.stack)
        
  
  watch: ->
    @build() 
    for dir in (path.dirname(lib) for lib in @options.libs).concat @options.css, @options.paths
      continue unless path.existsSync(dir)
      try
        require('watch').watchTree dir, (file, curr, prev) =>
          if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
            console.log "#{file} changed.  Rebuilding."
            @build()
        console.log 'using watch.watchTree api to watch for changes'
      catch e
        fs.watch dir, (event, file) =>
          if file
            console.log "#{file} changed. Rebuilding."
          else
            console.log "Something changed. Rebuilding."
        console.log 'using fs.watch api to watch for changes'
  
  serverWatch: ->
    @serverBuild()
    for dir in (path.resolve(process.cwd(), lib) for lib in @serverOptions.paths)
      continue unless path.existsSync(dir)
      try
        require('watch').watchTree dir, (file, curr, prev) =>
          if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
            console.log "#{file} changed.  Rebuilding Server."
            @serverBuild()
        console.log 'using watch.watchTree api to watch for server changes'
      catch e
        fs.watch dir, (event, file) =>
          if file
            console.log "#{file} changed. Rebuilding Server."
          else
            console.log "Somehing changed. Rebuilding Server."
        console.log 'using fs.watch api to watch for server changes'

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
  
  cssPackage: ->
    pack = css.createPackage(@options.css)
    @cssPackage = ->
      return pack
    pack

  hemPackage: ->
    pack = package.createPackage(
      dependencies: @options.dependencies
      paths: @options.paths
      libs: @options.libs
    )
    @hemPackage = ->
      return pack
    pack
    
  specsPackage: ->
    @specsPackage = specs.createPackage(@options.specs)

module.exports = Hem