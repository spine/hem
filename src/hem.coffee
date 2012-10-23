path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
connect   = require('connect')
httpProxy = require('http-proxy')
http      = require('http')

compilers = require('./compilers')
Package   = require('./package')
css       = require('./css')

argv = optimist.usage([
  '  usage: hem COMMAND',
  '    server  start a dynamic development server',
  '    build   serialize application to disk',
  '    watch   build & watch disk for changes'
  '    test    build and run tests'
  '    clean   clean compiled files'
].join("\n"))
.alias('p', 'port')
.alias('d', 'debug')
.alias('t', 'tests')
.alias('s', 'slug')
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

  options:
    # TODO: make a default spine app configuration available??
    slug:         argv.slug       or './slug.json'
    port:         argv.port       or 9294
    host:         argv.host       or 'localhost'
    useProxy:     argv.useProxy   or false
    apiHost:      argv.apiHost    or 'localhost'
    apiPort:      argv.apiPort    or 8080
    proxyPort:    argv.proxyPort  or 8001
    
    paths:        ['./app']
    public:       './public'
    appPath:      '/'
    css:          './css'
    cssPath:      '/application.css'
    libs:         []
    dependencies: []
    jsPath:       '/application.js'

    testPublic:   './test/public'
    testPath:     '/test'
    specs:        './test/specs'
    specsPath:    '/specs.js'

  constructor: (options = {}) ->
    @options[key] = value for key, value of options
    # quick check to make sure slug file exists
    if fs.existsSync(@options.slug)
      @options[key] = value for key, value of @readSlug()
    else
      throw new Error "Unable to find #{@options.slug} file."

  server: ->
    # remove old compiled files are removed so its always dynamic (TODO: make this an option??)
    @removeOldBuilds()

    # create mappings
    app = connect()

    # setup dynamic files
    app.use("/segway/healthlink/application.js", @hemPackage().middleware)
    app.use("/segway/healthlink/application.css", @cssPackage().middleware)
    app.use("/test/specs.js", @specsPackage().middleware)

    # setup static folders
    app.use("/segway/healthlink", connect.static(@options.public))
    app.use("/test", connect.static(@options.testPublic))

    # setup proxy
    app.use("/segway", @createRoutingProxy(host:'localhost', port: 8080))
    
    # start server
    http.createServer(app).listen(@options.port)

  createRoutingProxy: (options = {}) ->
    proxy = new httpProxy.RoutingProxy()
    return (req, res, next) ->
      # TODO make the additional path another options setting to pass in
      req.url = "/segway#{req.url}"
      proxy.proxyRequest(req, res, options)

  removeOldBuilds: ->
    packages = [@hemPackage(), @cssPackage(), @specsPackage()]
    pkg.unlink() for pkg in packages

  build: (options = { hem: true, css: true, specs: true }) ->
    ## TODO: make generic css/js packages that can be looped over
    ## TODO: create build method on package to compile and write file
    if options.hem
      console.log "Building hem target: #{@hemPackage().target}"
      source = @hemPackage().compile(not argv.debug)
      fs.writeFileSync(@hemPackage().target, source)

    if options.css
      console.log "Building css target: #{@cssPackage().target}"
      source = @cssPackage().compile()
      fs.writeFileSync(@cssPackage().target, source)

    if options.specs
      console.log "Building specs target: #{@specsPackage().target}"
      source = @specsPackage().compile()
      fs.writeFileSync(@specsPackage().target, source)

  watch: () ->
    @build()
    @executeTestacular() if argv.tests
    for dir in (path.dirname(lib) for lib in @options.libs).concat @options.css, @options.paths, @options.specs
      continue unless fs.existsSync(dir)
      require('watch').watchTree dir, { persistent: true, interval: 1000 },  (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          console.log "#{file} changed.  Rebuilding."
          # quick hack to only build the package that changed, will have a better
          # fix in a later commit that redos the package structure
          specsBuild = ("./" + file).indexOf(@options.specs) == 0
          hemBuild = not specsBuild
          @build({ specs: specsBuild, hem: hemBuild }) # TODO: pass in different build option based on file changed??

  test: ->
    @build()
    @executeTestacular(true)

  executeTestacular: (singleRun = false) ->
    unless @testactular
      @testacular = require('testacular').server
      # create config file to pass into server
      # TODO: eventually add files to test dynamically
      # TODO: add browsers to test too
      testConfig =
        configFile: require.resolve("../assets/testacular.conf.js")
        basePath: process.cwd()
        singleRun: singleRun
        browsers: ['PhantomJS']
        logLevel: 2
        reporters: ['progress']
      # start testacular serveri
      @testacular.start(testConfig)

  exec: (command = argv._[0]) ->
    return help() unless @[command]
    switch command
      when 'build'  then console.log 'Build application'
      when 'watch'  then console.log 'Watching application'
      when 'test'   then console.log 'Test application'
      when 'clean'  then console.log 'Clean application'
    @[command]()

  # Private

  readSlug: (slug = @options.slug) ->
    return {} unless slug and fs.existsSync(slug)
    JSON.parse(fs.readFileSync(slug, 'utf-8'))

  cssPackage: ->
    css.createPackage(
      path   : @options.css
      target : path.join(@options.public, @options.cssPath)
    )

  hemPackage: ->
    Package.createPackage(
      dependencies : @options.dependencies
      paths        : @options.paths
      libs         : @options.libs
      target       : path.join(@options.public, @options.jsPath)
    )

  specsPackage: ->
    Package.createPackage(
      identifier : 'specs'
      paths      : @options.specs
      target     : path.join(@options.testPublic, @options.specsPath)
      extraJS    : "require('lib/setup'); for (var key in specs.modules) specs(key);"
      test       : true
    )

module.exports = Hem
