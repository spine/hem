fs       = require('fs-extra')
path     = require('path')
uglifyjs = require('uglify-js')
utils    = require('./utils')
Events   = require('./events')
Log      = require('./log')
Job      = require('./job')

# ------- Application Class

class Application
  constructor: (name, config, argv) ->
    @argv = argv
    @name = name

    # apply defaults if any
    if (config.base)
      try
        # make sure we don't modify the original assets (which is cached by require)
        baseConfig = utils.loadAsset('config/' + config.base)
        defaults   = utils.extend({}, baseConfig)
      catch err
        Log.errorAndExit "Invalid 'base' value provided: " + config.base
      # create updated config mapping by merging with default values
      config = utils.extend defaults, config

    # folder and url settings
    # change to @path
    @route  = config.route
    @root   = config.root
    @static = []
    @jobs   = {}

    # dependecy on other apps?
    @depends = utils.toArray(config.depends or "")

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

    # configure jobs
    for jobname, value of config.jobs
      job = new Job(@, jobname, value)
      @jobs[jobname] = job if job.tasks.length > 0

  isMatchingRoute: (route) ->
    # strip out any potential versioning applied to request file
    if @jobs.version
      # TODO: use event system instead
      params = route: route
      @jobs.version.run(params)
      route = params.route
    # compare against task route values
    for task in @jobs.build.tasks
      return task.run() if route is task.route
    # return nothing
    return

  exec: (jobname, params) ->
    job = @jobs[jobname]
    if job
      job.run(params)
    else
      Log.errorAndExit "ERROR: #{jobname} job has not been configured."

  clean: ->
    @exec 'clean'

  build: ->
    @exec 'build'

  deploy: ->
    @exec 'deploy'

  test: ->
    @exec 'test'

  applyRoot: (value, returnArray = true) ->
    # TODO: eventually use the Hem.home directory value if the home
    #       value is different from the process.cwd() value?!
    values = utils.toArray(value)
    values = values.map (value) =>
      if utils.startsWith(value, "." + path.sep)
        value
      else
        utils.cleanPath(@root, value)
    if returnArray
      values
    else
      values[0]

  applyRoute: (values...) ->
    values.unshift(@route) if @route
    utils.cleanRoute.apply(utils, values)

# ------- Public Functions

module.exports.create = (name, config, argv) ->
  return new Application(name, config, argv)



