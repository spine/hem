path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
connect   = require('connect')
httpProxy = require('http-proxy')
http      = require('http')
compilers = require('./compilers')
Package   = require('./package')

# ------- Commandline arguments

argv = optimist.usage([
  'usage:\nhem COMMAND',
  '    server  :start a dynamic development server',
  '    build   :serialize application to disk',
  '    watch   :build & watch disk for changes'
  '    test    :build and run tests'
  '    clean   :clean compiled targets'
].join("\n"))
.alias('p', 'port').describe('p',':hem server port')
.alias('d', 'debug').describe('d',':all compilations use debug mode')
.alias('t', 'test').describe('t',':run testacular while using watch')
.alias('s', 'slug').describe('s',':run hem using a specified slug file')
.alias('b', 'browser').describe('b',':run testacular using the supplied browser[s]')
.alias('n', 'noBuild').describe('n',':turn off dynamic builds during server mode')
.describe('v',':make hem more talkative(verbose)')
.argv

# set command and targets properties
argv.command = argv._[0]
argv.targets = argv._[1..]

# set compilers debug mode
compilers.DEBUG = argv.debug and true or false


# ------- Global Functions

help = ->
  optimist.showHelp()
  process.exit()

# ------- Hem Class

class Hem
  @exec: (command, options) ->
    (new @(options)).exec(command)

  @include: (props) ->
    @::[key] = value for key, value of props

  compilers: compilers

  # TODO: include way to handle older slug.json files?? backwards compatible??
  slug: argv.slug or './slug.json'

  options:
    server:
      port: 9294
      host: 'localhost'

  constructor: (options = {}) ->
    @options[key] = value for key, value of options
    # quick check to make sure slug file exists
    if fs.existsSync(@slug)
      @options[key] = value for key, value of @readSlug()
    else
     console.log "ERROR: Unable to find #{@slug} file in current directory"
     process.exit(1)
    # setup packages from options/slug
    @packages = (@createPackage(name, config) for name, config of @options.packages)
    # allow overrides
    @options.server.port = argv.port if argv.port
    @options.server.host or= ""

  server: ->
    # create app
    app = connect()

    # setup dynamic targets first
    for pkg in @packages when not argv.n
      # determine url if its not already set
      pkg.url or= @determinePackageUrl(pkg)
      # exit if pkg.url isn't defined
      if not pkg.url
        console.log "ERROR: Unable to determine url mapping for package: #{pkg.name}"
        process.exit(1)
      # set route
      console.log "Map package '#{pkg.name}' to #{pkg.url}" if argv.v
      app.use(pkg.url, pkg.middleware(argv.debug))

    # setup static routes
    @options.routes or= []
    for route in @options.routes
      url   = Object.keys(route)[0]
      value = route[url]
      if (typeof value is 'string')
        # make sure path exists
        if fs.existsSync(value)
          # test if file is directory or file....
          if fs.lstatSync(value).isDirectory()
            console.log "Map directory '#{value}' to #{url}" if argv.v
            app.use(url, connect.static(value))
          else
            console.log "Fallback resource '#{value}' for #{url}" if argv.v
            app.use(url, do (value) ->
              (req, res) ->
                fs.readFile(value, (err, data) ->
                  if err
                    res.writeHead(404)
                    res.end(JSON.stringify(err))
                    return
                  res.writeHead(200)
                  res.end(data)
                )
            )
        else
          console.log "ERROR: The folder #{value} does not exist."
          process.exit(1)
      else if value.host
        # setup proxy
        console.log "Proxy requests from #{url} to #{value.host}" if argv.v
        app.use(url, @createRoutingProxy(value))
        @patchServerResponseForRedirects(@options.server.port, value) if value.patchRedirect
      else
        throw new Error("Invalid route configuration for #{url}")

    # start server
    http.createServer(app).listen(@options.server.port, @options.server.host)

  clean: () ->
    targets = argv.targets
    cleanAll = targets.length is 0
    pkg.unlink() for pkg in @packages when pkg.name in targets or cleanAll

  build: ->
    @clean()
    @buildTargets(argv.targets)

  watch: ->
    targets = argv.targets
    @buildTargets(targets)
    # also run testacular tests if -t is passed in the command line
    @startTestacular(targets, false) if argv.test
    # begin watching package targets
    watchAll = targets.length is 0
    pkg.watch() for pkg in @packages when pkg.name in targets or watchAll

  test: ->
    @buildTargets(argv.targets)
    @startTestacular(argv.targets)

  exec: (command = argv.command) ->
    return help() unless @[command]
    # TODO: make sure argv.targets exist before proceeding??
    switch command
      when 'build'  then console.log 'Build application'
      when 'watch'  then console.log 'Watching application'
      when 'test'   then console.log 'Test application'
      when 'clean'  then console.log 'Clean application'
      when 'server' then console.log "Starting Server at #{@options.server.host}:#{@options.server.port}"
    @[command]()

  # ------- Private Functions

  readSlug: (slug = @slug) ->
    return {} unless slug and fs.existsSync(slug)
    JSON.parse(fs.readFileSync(slug, 'utf-8'))

  createPackage: (name, config) ->
    pkg = new Package(name, config, argv)

  buildTargets: (targets = []) ->
    buildAll = targets.length is 0
    # TODO: preset a versionAddOn var if argv.setVersion 
    #if argv.setVersion and argv.version is null
      #version = new Date().getUTCMilliseconds()  #or something like this...
    pkg.build(not argv.debug) for pkg in @packages when pkg.name in targets or buildAll
    # TODO: add auto build of an application.cache file with relevant target files pre-filled
    #cache = pkg.compileCache()

  createRoutingProxy: (options = {}) ->
    proxy = new httpProxy.RoutingProxy()
    # additional options
    options.hostPath or= ""
    # return function used by connect to access proxy
    return (req, res, next) ->
      req.url = "#{options.hostPath}#{req.url}"
      proxy.proxyRequest(req, res, options)

  patchServerResponseForRedirects: (port, config) ->
      writeHead = http.ServerResponse.prototype.writeHead
      http.ServerResponse.prototype.writeHead = ->
        @.emit('header') if (!@._emittedHeader)
        @._emittedHeader = true
        [ status, head ] = arguments
        if status in [301,302]
          oldLocation = new RegExp(":\/\/#{config.host}:?[0-9]*")
          newLocation = "://localhost:#{port}"
          head.location = head.location.replace(oldLocation,newLocation)
        return writeHead.apply(this, arguments)

  startTestacular: (targets = [], singleRun = true) ->
    # use custom testacular config file provided by user
    testConfig = fs.existsSync(argv.test) and fs.realpathSync(argv.test)

    # create config file to pass into server if user doesn't supply a file to use
    testConfig or=
      configFile : require.resolve("../assets/testacular.conf.js")
      singleRun  : singleRun
      basePath   : process.cwd()
      logLevel   : 'error'
      browsers   : argv.browser and argv.browser.split(/[ ,]+/) or ['PhantomJS']
      files      : @createTestacularFileList()

    # start testacular server
    require('karma').server.start(testConfig)

  createTestacularFileList: () ->
    # look at at test type to see what assets we add
    fileList = [require.resolve("../node_modules/karma/adapter/lib/jasmine.js"),
                require.resolve("../node_modules/karma/adapter/jasmine.js")]
    # TODO: would we ever need a way to specificy only certain files to test??
    # Perhaps a special package type that just lists a group of packages to build/test??
    # "testGroup" : [ "spine", "test" ], then check typeof array to use this group?? Would need a
    # new function to create the targets array used by the build/watch/clean methods...
    #
    # loop over javascript packages and add their targets
    fileList.push pkg.target for pkg in @packages when pkg.isJavascript()
    return fileList

  determinePackageUrl: (pkg) ->
    # loop over server paths and see which one is the best match with the pkg.target
    bestMatch = {}
    for route in @options.routes
      url   = Object.keys(route)
      dir   = route[url]
      # TODO: should convert to full path before attempting match
      if pkg.target.indexOf(dir) == 0 and (!bestMatch.url or bestMatch.dir.length < dir.length)
        bestMatch.url = url + pkg.target.slice(dir.length)
        bestMatch.dir = dir
    bestMatch.url

module.exports = Hem

