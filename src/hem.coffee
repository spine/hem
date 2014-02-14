fs       = require('fs')
path     = require('path')
optimist = require('optimist')
coffee   = require('coffee-script/register')

# ------- Commandline arguments

# TODO: make watch just a switch, not an actual command...
argv = optimist.usage([
  'usage:\nhem COMMAND',
  '    server  :start a dynamic development server',
  '    build   :serialize application to disk',
  '    test    :build and run tests'
  '    clean   :clean compiled targets'
  '    deploy  :deploy the application files'
].join("\n"))
.alias('p', 'port').describe('p',':hem server port')
.alias('h', 'host').describe('h',':hem server host')
.alias('c', 'compress').describe('c',':all compilations are compressed/minified')
.alias('w', 'watch').describe('w',':watch files')
.alias('s', 'slug').describe('s',':run hem using a specified slug file')
.alias('n', 'nocolors').describe('n',':disable color in console output')
.alias('v', 'verbose').describe('v',':make hem more talkative(verbose)')
.alias('g', 'grep').describe('g',':only run specific modules during test')
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
application = require('./application')
events      = require('./events')
job         = require('./job')

# supply argv object to modules
compilers.argv  = argv

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

  # set home directory for utils functions
  @home: process.cwd()

  # ------- instance variables

  # emtpy options map and applications list
  options : {}
  apps    : []
  allApps : []

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

    # allow overrides from command line
    @options.hem.port = argv.port if argv.port
    @options.hem.host = argv.host if argv.host

    # setup applications from options/slug
    for name, config of @options
      continue if name is "hem" or typeof config is 'function'
      @allApps.push application.create(name, config, argv)

  # ------- Command Functions

  server: ->
    app   = server.start(@)
    value = "http://#{@options.hem.host or "*"}:#{@options.hem.port}"
    log "Starting Server at <blue>#{value}</blue>"
    # handle watch flag (default to true)
    if @options.hem.serverWatch
      argv.watch or= @options.hem.serverWatch
    else
      argv.watch or= true
    # handle events
    events.emit("server", app)
    
  clean: ->
    app.clean() for app in @apps

  build: ->
    app.build() for app in @apps
  
  deploy: ->
    app.deploy() for app in @apps

  test: ->
    app.test() for app in @apps

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
    # start watch if argv supplied
    if argv.watch and argv.command not in ['clean', 'deploy']
      app.watch(command) for app in @apps
    # hope this works :o)
    @[command]()

  # ------- Private Functions

  readSlug: (slug) ->
    # first make sure slug file exists
    slugPath = path.resolve(slug)
    try
      slugPath = require.resolve(slugPath)
    catch error
      console.log error
      log.errorAndExit("Couldn't find slug file #{path.dirname(slugPath)}")

    # set home directory to slug directory
    Hem.home = path.dirname(slugPath)

    # next try to require
    try
      delete require.cache[slugPath]
      @slug = require(slugPath)
    catch error
      log.errorAndExit("Couldn't load slug file #{slugPath}.")

    # return config portion of slug file
    @slug.config or @slug

  getTargetApps: (targets = argv.targets) ->
    targetAll = targets.length is 0
    (app for app in @allApps when app.name in targets or targetAll)


# ------- Expose internal modules for customization

Hem.compilers = compilers
Hem.log       = log
Hem.events    = events
Hem.tasks     = job.tasks
Hem.argv      = argv
Hem.utils     = utils

# ------- Public Export

module.exports = Hem

