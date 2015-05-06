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
.alias('h', 'host').describe('h',':hem server host')
.alias('c', 'compress').describe('c',':all compilations are compressed/minified')
.alias('w', 'watch').describe('w',':watch files when running tests')
.alias('s', 'slug').describe('s',':run hem using a specified slug file')
.alias('n', 'nocolors').describe('n',':disable color in console output')
.alias('v', 'verbose').describe('v',':make hem more talkative(verbose)')
.alias('g', 'grep').describe('g',':only run specific modules during test')
.alias('r', 'runner').describe('r',':override the default test runner')
.argv

# set command and targets properties
argv.command = argv._[0]
argv.targets = argv._[1..]

# disable colors
require("sty").disable() if !!argv.nocolors

# turn on/off verbose logging
log = require('./log')
log.VERBOSE = argv.v = !!argv.v

# ------- perform requires

utils       = require('./utils')
compilers   = require('./compilers')
server      = require('./server')
testing     = require('./test')
application = require('./package')
versioning  = require('./versioning')
events      = require('./events')

# supply argv object to module

compilers.argv   = argv
application.argv = argv

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

  # ------- instance variables

  # emtpy options map and applications list
  options : {}
  apps    : []
  allApps : []
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
    @options.hem.port or= 9294
    @options.hem.host or= "localhost"

    # test defaults
    @options.hem.test or= {}
    @options.hem.test.runner     or= "karma"
    @options.hem.test.reporters  or= "progress"
    @options.hem.test.frameworks or= "jasmine"

    # allow overrides from command line
    @options.hem.port = argv.port if argv.port
    @options.hem.host = argv.host if argv.host
    @options.hem.test.runner = argv.runner if argv.runner

    # setup applications from options/slug
    for name, config of @options
      continue if name is "hem" or typeof config is 'function'
      @allApps.push application.create(name, config, @, argv)

  # ------- Command Functions

  server: ->
    value = "http://#{@options.hem.host or "*"}:#{@options.hem.port}"
    log "Starting Server at <blue>#{value}</blue>"
    app = server.start(@)
    events.emit("server", app)
    # make sure watch is going to recompile immediately
    app.watch() for app in @apps

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
    @build()
    # set test options
    testOptions = @options.hem.tests or {}
    testOptions.basePath or= @home

    # check for watch mode
    if argv.watch
      @watch()
      testOptions.singleRun = false
    else
      testOptions.singleRun = true

    # run tests
    testing.run(@apps, testOptions)

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
    return help() unless @[command]
    # reset the apps list based on command line args
    @apps = @getTargetApps()
    # customize hem
    @slug.custom?(@)
    # hope this works :o)
    @[command]()

  # ------- Private Functions

  readSlug: (slug) ->
    # first make sure slug file exists
    slugPath = path.resolve(slug)
    try
      slugPath = require.resolve(slugPath)
    catch error
      log.errorAndExit("Couldn't find slug file #{path.dirname(slugPath)}")

    # set home directory to slug directory
    @home = path.dirname(slugPath)

    # next try to require
    try
      delete require.cache[slugPath]
      @slug = require(slugPath)
    catch error
      log.errorAndExit("Couldn't load slug file #{slugPath}: " + error.message)

    # return config portion of slug file
    @slug.config or @slug

  getTargetApps: (targets = argv.targets) ->
    targetAll = targets.length is 0
    (app for app in @allApps when app.name in targets or targetAll)

  buildApps: () ->
    app.build() for app in @apps

  module: (name) ->
    switch name
      when "compilers" then compilers
      when "events" then events
      when "reporters" then testing.phantom.reporters
      when "versioning" then versioning
      when "log" then log
      else
        throw new Error("Unknown module name #{name}")

module.exports = Hem

