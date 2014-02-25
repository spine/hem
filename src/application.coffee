fs       = require('fs-extra')
path     = require('path')
uglifyjs = require('uglify-js')
glob     = require('globule')
Utils    = require('./utils')
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
        baseConfig = Utils.loadAsset('config/' + config.base)
        defaults   = Utils.extend({}, baseConfig)
      catch err
        Log.errorAndExit "Invalid 'base' value provided: " + config.base
      # create updated config mapping by merging with default values
      config = Utils.extend defaults, config

    # basic app settings
    @route    = config.route
    @root     = config.root
    @static   = []
    @jobs     = {}
    @defaults = config.defaults or {}

    # set root variable, and possibly route
    unless @root
      # if application name is also a directory then assume that is root
      if Utils.isDirectory(@name)
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
        path : @applyRoot(value)

    # configure jobs
    for jobname, value of config.jobs
      job = new Job(@, jobname, value)
      @jobs[jobname] = job if job.tasks.length > 0

  # ---- Find matching routes

  isMatchingRoute: (route) ->
    # compare against task route values
    for task in @jobs.build.tasks when route is task.route
      result = @jobs.build.run(task.id)
      # if multiple builds, determine which matches
      if Array.isArray result
        for item in result
          return item if route is item.result
      # otherwise just return result
      else
        result
    # return nothing
    return

  # ---- Executing jobs

  watch: (jobname) ->
    job = @jobs[jobname]
    job.watch() if job

  exec: (jobname) ->
    job = @jobs[jobname]
    if job
      job.run()
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

  # ---- Helper functions

  applyRoot: (values) ->
    # remember what was passed in as a parameter
    returnArray = Array.isArray(values)
    # turn into array for next steps
    values = Utils.toArray(values)
    values = values.map (value) =>
      if Utils.startsWith(value, "." + path.sep)
        value
      else
        Utils.cleanPath(@root, value)
    # return results the same as what was passed in
    if returnArray then values else values[0]

  applyRoute: (values...) ->
    values.unshift(@route) if @route
    Utils.cleanRoute.apply(Utils, values)

  createPaths: (paths) ->
    new Path(@, path) for path in Utils.toArray(paths)

# ------- Path Class

class Path
  constructor: (app, options) ->
    # first check to see if options is string or object
    if typeof options is "string"
      if options.match /[*]/
        options =
          srcBase: ""
          src: options
      else
        # default to globbing everything under a folder name
        options =
          srcBase: options
          src: "**"

    # set default values
    options.commonjs ?= app.defaults.commonjs if app.defaults.commonjs?
    options.npm      ?= app.defaults.npm if app.defaults.npm?

    # set values
    @src      = options.src
    @srcBase  = app.applyRoot(options.srcBase or "")
    @target   = options.target if options.target
    @commonjs = options.commonjs if options.commonjs
    @npm      = options.npm if options.npm

  walk: ->
    glob.find
      src        : @src
      srcBase    : @srcBase
      prefixBase : true # make sure we always include the srcBase in returned files

  # see if certain file is contained in glob
  contains: (file) ->
    glob.isMatch()

  # mapping:
  mapping: (destBase) ->
    glob.mapping({src: ["a.js", "b.js"], srcBase: "foo", destBase: "bar"})


# ------- Public Functions

module.exports.create = (name, config, argv) ->
  return new Application(name, config, argv)



