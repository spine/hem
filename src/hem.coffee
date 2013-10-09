fs       = require('fs')
path     = require('path')
optimist = require('optimist')

# ------- Commandline arguments

argv = optimist.usage([
  'usage:\nhem COMMAND',
  '    server  :start a dynamic development server',
  '    build   :serialize application to disk',
  '    watch   :build & watch disk for changes'
  '    test    :build and run tests'
  '    clean   :clean compiled targets'
  '    version :version the application files'
  '    check   :check slug file values'
].join("\n"))
.alias('p', 'port').describe('p',':hem server port')
.alias('c', 'compress').describe('c',':all compilations are compressed/minified')
.alias('w', 'watch').describe('w',':watch files when running tests')
.alias('s', 'slug').describe('s',':run hem using a specified slug file')
.alias('n', 'nocolors').describe('n',':disable color in console output')
.alias('v', 'verbose').describe('v',':make hem more talkative(verbose)')
.argv

# set command and targets properties
argv.command = argv._[0]
argv.targets = argv._[1..]

# disable colors
require("sty").disable() if !!argv.nocolors

# turn on/off verbose logging
log = require('./log')
log.VERBOSE = argv.v = !!argv.v

# save argv to utils class to allow access by other modules
utils = require('./utils')
utils.ARGV = argv

# ------- perform requires

compilers   = require('./compilers')
server      = require('./server')
testing     = require('./test')
application = require('./package')

# ------- Global Functions

help = ->
  log "<b>HEM</b> Version: <green>" + require('../package.json')?.version + "</green>\n"
  optimist.showHelp()
  process.exit()

# ------- Hem Class

class Hem

  @exec: (command, options) ->
    (new @(options)).exec(command)

  @middleware: (slug) ->
    hem = new Hem(slug)
    server.middleware(hem)

  # exposing globals for customization

  @compilers : compilers
  @events    : utils.events # TODO: eventuall get an event system going...

  # default values for server
  @defaults:
    hem:
      port: 9294
      host: "localhost"

  # ------- instance variables

  # emtpy options map and applications list
  options : {}
  apps    : []
  home    : process.cwd()

  # ------- Constructor

  constructor: (options) ->
    # handle slug file options
    switch typeof options
      when "string"
        slug = options
      when "object"
        @options = options
      else
        slug or= argv.slug or 'slug'

    # if given a slug file, attempt to load
    @options = @readSlug(slug) if slug

    # make sure some defaults are present
    @options.hem or= {}
    @options.hem.port   or= Hem.defaults.hem.port
    @options.hem.host   or= Hem.defaults.hem.host

    # allow overrides from command line
    @options.hem.port = argv.port if argv.port

    # setup applications from options/slug
    for name, config of @options
      continue if name is "hem"
      @apps.push application.createApplication(name, config, @)

  # ------- Command Functions

  server: ->
    value = "http://#{@options.hem.host or "*"}:#{@options.hem.port}"
    log "Starting Server at <blue>#{value}</blue>"
    app = server.start(@)
    Hem.events.emit("server-start", app)

  clean: ->
    app.unlink() for app in @apps

  build: ->
    @clean()
    @buildApps()

  version: ->
    app.version() for app in @apps

  watch: ->
    @buildApps()
    app.watch() for app in @apps

  test: ->
    # set test options
    testOptions =
      basePath: @home
    # check for watch mode
    if argv.watch
      @watch()
      testOptions.singleRun = false
    else
      @buildApps()
      testOptions.singleRun = true
    # run tests
    testing.run(@apps, options)

  check: ->
    printOptions = showHidden: false, colors: !argv.nocolors, depth: null
    inspect = require('util').inspect
    # print hem configuration
    log "> Configuration for <green>hem</green>:"
    console.log(inspect(@options.hem, printOptions))
    log ""
    # print app configurations
    for app in @apps
      log "> Configuration values for <green>#{app.name}</green>:"
      console.log(inspect(app, printOptions))
      log ""

  exec: (command = argv.command) ->
    # handle empty arguments
    return help() unless @[command]

    # reset the apps list based on command line args
    @apps = @getTargetApps()

    # hope this works :o)
    @[command]()

  # ------- Private Functions

  readSlug: (slug) ->
    # first make sure slug file exists
    slugPath = path.resolve(slug)
    try
      slugPath = require.resolve(slugPath)
    catch error
      log.errorAndExit("Couldn't find slug file #{slugPath}. #{error}")

    # set home directory to slug directory
    Hem.home = path.dirname(slugPath)

    # next try to require
    try
      delete require.cache[slugPath]
      slug = require(slugPath)
      slug?(Hem) or slug
    catch error
      log.errorAndExit("Couldn't load slug file #{slugPath}. #{error}")

  getTargetApps: (targets = argv.targets) ->
    targetAll = targets.length is 0
    (app for app in @apps when app.name in targets or targetAll)

  buildApps: () ->
    app.build() for app in @apps

module.exports = Hem

