path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
connect   = require('connect')
httpProxy = require('http-proxy')
http      = require('http')
compilers = require('./compilers')
versions  = require('./versioning')
Package   = require('./package')

# ------- Commandline arguments

argv = optimist.usage([
  'usage:\nhem COMMAND',
  '    server  :start a dynamic development server',
  '    build   :serialize application to disk',
  '    watch   :build & watch disk for changes'
  '    test    :build and run tests'
  '    clean   :clean compiled targets'
  '    version :version the application files'
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
compilers.DEBUG   = !!argv.debug
compilers.VERBOSE = !!argv.v

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

  errorAndExit: (error) ->
    console.log "ERROR: #{error}"
    process.exit(1)

  constructor: (options = {}) ->
    @options[key] = value for key, value of options
    # quick check to make sure slug file exists
    if fs.existsSync(@slug)
      @options[key] = value for key, value of @readSlug()
    else
      @errorAndExit "Unable to find #{@slug} file in current directory"
    # if versioning turned on, pass in correct module to config
    if @options.version
      @options.version.type or= "package"
      @vertype = versions[@options.version.type]
      # make sure version.type is valid
      if not @vertype
        @errorAndExit "Incorrect type value for versioning (#{@options.version.type})"
    # allow overrides and set defaults
    @options.server.port = argv.port if argv.port
    @options.server.host or= ""
    @options.routes or= []
    # setup packages from options/slug
    @packages = (@createPackage(name, config) for name, config of @options.packages)

  # TODO: move server code to server.coffee file!
  server: ->
    # create app
    app = connect()
    
    # setup dynamic targets first
    for pkg in @packages when not argv.n
      # determine url if its not already set
      pkg.url or= @determineUrlFromRoutes(pkg)
      # exit if pkg.url isn't defined
      if not pkg.url
        @errorAndExit "Unable to determine url mapping for package: #{pkg.name}"
      console.log "Map package '#{pkg.name}' to #{pkg.url}" if argv.v
    
    # setup middleware to server packages
    app.use(@middleware(argv.debug))

    # setup static routes
    for route in @options.routes
      url   = Object.keys(route)[0]
      value = route[url]
      if (typeof value is 'string')
        # make sure path exists
        if not fs.existsSync(value)
          @errorAndExit "The folder #{value} does not exist."
        console.log "Map directory '#{value}' to #{url}" if argv.v
        app.use(url, connect.static(value))
      else if value.host
        # setup proxy
        console.log "Proxy '#{url}' to #{value.host}:#{value.port}#{value.hostPath}" if argv.v
        app.use(url, @createRoutingProxy(value))
        @patchServerResponseForRedirects(@options.server.port, value) if value.patchRedirect
      else
        @errorAndExit "Invalid route configuration for #{url}"

    # start server
    http.createServer(app).listen(@options.server.port, @options.server.host)

  clean: () ->
    targets = argv.targets
    cleanAll = targets.length is 0
    pkg.unlink() for pkg in @packages when pkg.name in targets or cleanAll

  build: ->
    @clean()
    @buildTargets(argv.targets)

  version: ->
    if not @vertype
      console.error "ERROR: Versioning not enabled in slug.json"
      return
    @vertype.updateFiles(@options.version.files, @packages)

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
    pkg.build(not argv.debug) for pkg in @packages when pkg.name in targets or buildAll

  createRoutingProxy: (options = {}) ->
    proxy = new httpProxy.RoutingProxy()
    # additional options
    options.hostPath or= ""
    options.port or= 80
    # return function used by connect to access proxy
    return (req, res, next) ->
      req.url = "#{options.hostPath}#{req.url}"
      proxy.proxyRequest(req, res, options)

  patchServerResponseForRedirects: (port, config) ->
      writeHead = http.ServerResponse.prototype.writeHead
      http.ServerResponse.prototype.writeHead = (status) ->
        if status in [301,302]
          headers =  @_headers
          oldLocation = new RegExp(":\/\/#{config.host}:?[0-9]*")
          newLocation = "://localhost:#{port}"
          headers.location = headers.location.replace(oldLocation,newLocation)
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

  middleware: (debug) =>
    (req, res, next) =>
      # only deal with js/css files
      url = require("url").parse(req.url)?.pathname.toLowerCase() or ""
      if not url.match(/\.js|\.css/)
        next()
        return
      # strip out any potential versioning 
      if @vertype
        url = @vertype.trimVersion(url)
      # loop over pkgs and call compile
      for pkg in @packages
        if url is pkg.url
          # TODO: keep (and return) in memory build if there hasn't been any changes??
          str = pkg.compile(not debug)
          res.charset = 'utf-8'
          res.setHeader('Content-Type', pkg.contentType)
          res.setHeader('Content-Length', Buffer.byteLength(str))
          res.end((req.method is 'HEAD' and null) or str)
          return
      # no matches, go to next middleware
      next()

  determineUrlFromRoutes: (pkg) ->
    bestMatch = {}
    for route in @options.routes
      url = Object.keys(route)
      dir = route[url]
      # compare against package target
      if pkg.target.indexOf(dir) == 0 and (!bestMatch.url or bestMatch.dir.length < dir.length)
        bestMatch.url = url + pkg.target.slice(dir.length)
        bestMatch.dir = dir
    bestMatch.url.toLowerCase()

module.exports = Hem

