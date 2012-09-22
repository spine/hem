path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
strata    = require('strata')
compilers = require('./compilers')
Package   = require('./package')
css       = require('./css')
spawn     = require('child_process').spawn
http      = require('http')
httpProxy = require('http-proxy')

argv = optimist.usage([
  '  usage: hem COMMAND',
  '    server  start a dynamic development server',
  '    build   serialize application to disk',
  '    watch   build & watch disk for changes'
  '    test    build and run tests'
].join("\n"))
.alias('p', 'port')
.alias('d', 'debug')
.alias('t', 'tests')
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
    # TODO orgainzie this so we can have multiple packages, based on target use appropiate package setup
    # package:
    #   specs:
    #     path: ""
    #     target: ""
    #     urlMap: ""
    #     dependicies: ""
    #     libs: ""
    #     test: ""
    #     callback: ""
    slug:         './slug.json'
    paths:        ['./app']
    
    port:         process.env.PORT or argv.port or 9294
    host:         argv.host or 'localhost'
    useProxy:     argv.useProxy or false
    apiHost:      argv.apiHost or 'localhost'
    apiPort:      argv.apiPort or 8080
    proxyPort:    argv.proxyPort or 8001
    
    public:       './public'
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

    # setup strata instance
    strata.use(strata.contentLength)

    # get dynamically compiled javascript/css files
    strata.get(@options.cssPath, @cssPackage().createServer())
    strata.get(@options.jsPath, @hemPackage().createServer())

    # get static public folder
    if fs.existsSync(@options.public)
      strata.use(strata.file, @options.public, ['index.html', 'index.htm'])

    # handle test directory
    if fs.existsSync(@options.testPublic)
      strata.map @options.testPath, (app) =>
        app.get(@options.specsPath, @specsPackage().createServer())
        app.use(strata.file, @options.testPublic, ['index.html', 'index.htm'])

    # start server
    strata.run(port: @options.port, host: @options.host)
    # Optionally setup the proxyServer to conditionally route requests.
    # The spine app and the api need to appear to the browser to be coming from
    # the same host and port to avoid crossDomain ajax issues.
    # Ultimately it may be a good idea to configure an api server to accept
    # calls from other domains but sometimes not... 
    if @options.useProxy
      console.log "proxy server @ http://localhost:#{@options.proxyPort}"
      proxy = new httpProxy.RoutingProxy()
      startsWithSpinePath = new RegExp("^#{@options.baseSpinePath}")
      #console.log 'my spine regex base path is... ', startsWithSpinePath
      http.createServer (req, res) =>
        if startsWithSpinePath.test(req.url)
          req.url = req.url.replace(@options.baseSpinePath, '/')
          #console.log 'spine url turned into : ', req.url
          proxy.proxyRequest(req, res, {
            host: @options.host
            port: @options.port
          })
        else
          #console.log 'off to api : ', req.url
          proxy.proxyRequest(req, res, {
            host: @options.apiHost
            port: @options.apiPort
          })
      .listen(@options.proxyPort)

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

  watch: (callback) ->
    @build()
    @executeTestacular() if argv.tests
    # TODO: add watch() for each package and provide a call ball back which takes file that changed??
    for dir in (path.dirname(lib) for lib in @options.libs).concat @options.css, @options.paths, @options.specs
      continue unless fs.existsSync(dir)
      require('watch').watchTree dir, { persistent: true, interval: 1000 },  (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          console.log "#{file} changed.  Rebuilding."
          @build(specs: true) # TODO: pass in different build option based on file changed??
          

  test: ->
    # TODO: mark some packages at 'test', so loop over them and call build with callback
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
        logLevel: 1
      # start testacular serveri
      @testacular.start(testConfig)

  exec: (command = argv._[0]) ->
    return help() unless @[command]
    switch command
      when 'build'  then console.log 'Build application'
      when 'watch'  then console.log 'Watching application'
      when 'test'   then console.log 'Test application'
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
      extraJS    : "for (var key in specs.modules) specs(key);"
      test       : true
    )

module.exports = Hem
