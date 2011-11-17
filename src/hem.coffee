path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
strata    = require('strata')
compilers = require('./compilers')
package   = require('./package')
css       = require('./css')
specs     = require('./specs')

optimist.usage([
  '  usage: hem COMMAND',
  '    server  start a dynamic development server',
  '    build   serialize application to disk',
  '    watch   build & watch disk for changes'
].join("\n")).alias('p', 'port')

argv = optimist.argv

help = ->
  optimist.showHelp()
  process.exit()

class Hem
  @exec: (command, options) ->
    (new @(options)).exec(command)
  
  @include: (props) ->
    @::[key] = value for key, value of props
    
  compilers: compilers
    
  options: 
    slug:         './slug.json'
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

  constructor: (options = {}) ->
    @options[key] = value for key, value of options    
    @options[key] = value for key, value of @readSlug()
    
    @app = new strata.Builder
    
  server: =>
    @app.use(strata.contentLength);
      
    if @options.css
        @app.get(@options.cssPath, @cssPackage().createServer())
    @app.get(@options.jsPath, @hemPackage().createServer())
  
    @app.get(@options.specsPath, @specsPackage().createServer())
    @app.map @options.testPath, (app) =>
      @app.use(strata.static, @options.testPublic)

    @app.use(strata.static, @options.public)
    strata.run(@app, port: @options.port)
    
  build: =>
    source = @hemPackage().compile(true)
    fs.writeFileSync(path.join(@options.public, @options.jsPath), source)

    if @options.css
        source = @cssPackage().compile()
        fs.writeFileSync(path.join(@options.public, @options.cssPath), source)

  watch: =>
    @build()

    # watch CSS?
    cssDir = if @options.css then [@options.css] else []

    # extract the folders for each included lib
    libDir = []
    for lib in @options.libs
        libDir.push path.dirname(lib)

    # start watching
    for dir in cssDir.concat @options.paths, libDir
      require('watch').watchTree dir, (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          console.log "#{file} changed.  Rebuilding."
          @build()

          
  exec: (command = argv._[0]) =>
    return help() unless @[command]
    @[command]()
    console.log switch command
      when 'server' then "Starting server on: #{@options.port}"
      when 'build'  then 'Built application'
      when 'watch'  then 'Watching application'

  # Private
    
  readSlug: (slug = @options.slug) =>
    return {} unless slug and path.existsSync(slug)
    JSON.parse(fs.readFileSync(slug, 'utf-8'))
    
  cssPackage: =>
    css.createPackage(@options.css)

  hemPackage: =>
    package.createPackage(
      dependencies: @options.dependencies
      paths: @options.paths
      libs: @options.libs
    )
    
  specsPackage: =>
    specs.createPackage(@options.specs)

module.exports = Hem