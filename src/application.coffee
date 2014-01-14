fs         = require('fs-extra')
path       = require('path')
uglifyjs   = require('uglify-js')
uglifycss  = require('uglifycss')
utils      = require('./utils')
events     = require('./events')
log        = require('./log')
Dependency = require('./dependency')
Stitch     = require('./stitch')
Tasks      = require('./tasks.coffee')
Versioning = require('./versioning')

# ------- Application Class

class Application
  constructor: (name, config = {}) ->
    @name  = name

    # apply defaults, make this a require to load in?? TODO:
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
    @static = config.static or []
    @tasks  = config.tasks or []

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

    # configure js/css packages
    for key, value of config
      task = Tasks.create(key, value)
      @tasks.push(task) if task

    # configure versioning
    if config.version
      verType = Versioning[config.version.type]
      unless verType
        log.errorAndExit "Incorrect type value for version configuration: (#{config.version.type})"
      @versioning = new verType(@, config.version)

  getTestTask: ->
    for task in @tasks
      return task if task.test

  isMatchingRoute: (route) ->
    # strip out any versioning applied to file
    if @versioning
      route = @versioning.trim(route)
    # compare against package route values
    for task in @tasks
      return task if route is task.route
    # return nothing
    return

  unlink: ->
    log("Removing application: <green>#{@name}</green>")
    task.unlink() for task in @tasks

  build: ->
    log("Building application: <green>#{@name}</green>")
    task.execute() for task in @tasks

  watch: ->
    log("Watching application: <green>#{@name}</green>")
    dirs = (task.watch() for task in @tasks)
    # make sure dirs has valid values
    if dirs.length
      log.info("- Watching directories: <yellow>#{dirs}</yellow>")
    else
      log.info("- No directories to watch...")

  version: ->
    log("Versioning application: <green>#{@name}</green>")
    if @versioning
      @versioning.update()
    else
      log.errorAndExit "ERROR: Versioning not enabled in slug.json"

  applyRoot: (value) ->
    # TODO: eventually use the Hem.home directory value if the home
    # TODO: value is different from the process.cwd() value?!
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

create = (name, config) ->
  return new Application(name, config)

module.exports.create = create


