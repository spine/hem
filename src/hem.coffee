path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
compilers = require('./compilers')
server    = require('./server')
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
compilers.DEBUG   = server.DEBUG   = !!argv.debug
compilers.VERBOSE = server.VERBOSE = !!argv.v

# ------- Global Functions

help = ->
  console.log "HEM Version: " + require('../package.json')?.version + "\n"
  optimist.showHelp()
  process.exit()

# ------- Hem Class

class Hem

  @exec: (command, options) ->
    (new @(options)).exec(command)

  @include: (props) ->
    @::[key] = value for key, value of props

  @middleware: (slugFile) ->
    hem = new Hem(slugFile)
    server.middleware(hem.packages, hem.options.server)

  compilers: compilers

  # TODO: have a default options for spine pulled in, make it part of spine.app integration.
  # Create a framework interface to pull in, default to spine. This will in turn create the
  # slug.json to load in. Make this a separate node_module to pull in?
  options:
    framework: "spine"
    server:
      port: 9294
      host: "localhost"

  errorAndExit: (error) ->
    console.log "ERROR: #{error}"
    process.exit(1)

  constructor: (options = {}) ->
    # handle slug file
    if options is "string"
      slug = options
    else
      slug = argv.slug or './slug.json'
      @options[key] = value for key, value of options

    # TODO: add argv to options

    # quick check to make sure slug file exists
    if fs.existsSync(slug)
      @options[key] = value for key, value of @readSlug(slug)
    else
      @errorAndExit "Unable to find #{slug} file in current directory"

    # if versioning turned on, pass in correct module to config
    if @options.version
      @options.version.type or= "package"
      if not (@options.version.module = versions[@options.version.type])
        @errorAndExit "Incorrect type value for versioning (#{@options.version.type})"

    # allow overrides and set defaults
    @options.server.port = argv.port if argv.port
    @options.server.host or= ""
    @options.server.routes or= []

    # setup packages from options/slug
    @packages = (@createPackage(name, config) for name, config of @options.packages)

  # ------- Command Functions

  server: ->
    server.start(@packages, @options.server)

  clean: ->
    targets = argv.targets
    cleanAll = targets.length is 0
    pkg.unlink() for pkg in @packages when pkg.name in targets or cleanAll

  build: ->
    @clean()
    @buildTargets(argv.targets)

  version: ->
    # TODO: this should be done at the package level, not globally
    module = @options.version?.module
    files  = @options.version?.files
    if module and files
      module.updateFiles(files, @packages)
    else 
      console.error "ERROR: Versioning not enabled in slug.json"

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

  readSlug: (slug) ->
    return {} unless slug and fs.existsSync(slug)
    JSON.parse(fs.readFileSync(slug, 'utf-8'))

  createPackage: (name, config) ->
    pkg = new Package(name, config, argv)

  buildTargets: (targets = []) ->
    buildAll = targets.length is 0
    pkg.build(not argv.debug) for pkg in @packages when pkg.name in targets or buildAll

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

module.exports = Hem

