fs       = require('fs-extra')
path     = require('path')
uglifyjs = require('uglify-js')
utils    = require('./utils')
events   = require('./events')
log      = require('./log')
Tasks    = require('./tasks.coffee')

# ------- Application Class

class Application
  constructor: (name, config = {}, argv) ->
    @name  = name

    # TODO: apply defaults, make this a require to load in??
    if (config.extend)
      try
        # make sure we don't modify the original assets (which is cached by require)
        baseConfig = utils.loadAsset('config/' + config.extend)
        defaults   = utils.extend({}, baseConfig)
      catch err
        log.error "ERROR: Invalid 'extend' value provided: " + config.extend
        process.exit 1
      # create updated config mapping by merging with default values
      config = utils.extend(defaults, config)

    # folder and url settings
    @route  = config.route
    @root   = config.root
    @static = []
    @tasks  = {}

    # set root variable, and possibly route
    unless @root
      # if application name is also a directory then assume that is root
      if utils.isDirectory(@name)
        @root    = @name
        @route or= "/#{@name}"
      # otherwise just work from top level directory
      else
        @root    = "/"
        @route or= "/"

    # configure static routes with base root and route values
    for route, value of config.static
      @static.push
        url  : @applyRoute(route)
        path : @applyRoot(value)[0]

    # configure tasks
    for cmd, value of config.tasks
      @tasks[cmd] = []
      # helper method to run all tasks for a cmd and return a result
      @tasks[cmd].runAll = (options) ->
        result = undefined
        @forEach (task) ->
          result or= task.run(options)
      # create the actual tasks for the specific cmd (build, version, test...)
      for key, options of value
        options.argv = argv
        task = Tasks.createTask(app, key, options)
        @tasks[cmd].push(task)

  isMatchingRoute: (route) ->
    # strip out any versioning applied to request file
    if @tasks.version
      route = @tasks.version[0].run(route)
    # compare against package route values
    for task in @tasks.build
      return task.run() if route is task.route
    # return nothing
    return

  unlink: ->
    log("Removing application: <green>#{@name}</green>")
    task.unlink() for task in @tasks.build

  build: ->
    log("Building application: <green>#{@name}</green>")
    task.run() for task in @tasks.build

  watch: ->
    log("Watching application: <green>#{@name}</green>")
    dirs = (task.watch() for task in @tasks.build)
    # make sure dirs has valid values
    if dirs.length
      log.info("- Watching directories: <yellow>#{dirs}</yellow>")
    else
      log.info("- No directories to watch...")

  version: ->
    log("Versioning application: <green>#{@name}</green>")
    if @tasks.version
      task.run() for task in @tasks.version
    else
      log.errorAndExit "ERROR: Versioning tasks have not been configured."

  applyRoot: (value) ->
    # TODO: eventually use the Hem.home directory value if the home
    #       value is different from the process.cwd() value?!
    values = utils.toArray(value)
    values = values.map (value) =>
      if utils.startsWith(value, "." + path.sep)
        value
      else
        utils.cleanPath(@root, value)
    values

  applyRoute: (values...) ->
    values.unshift(@route) if @route
    utils.cleanRoute.apply(utils, values)

# ------- Public Functions

module.exports.create = (name, config, argv) ->
  return new Application(name, config, argv)



