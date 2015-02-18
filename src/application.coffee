separator = require('path').sep
Utils     = require('./utils')
Events    = require('./events')
Log       = require('./log')
Job       = require('./job')
FileSet   = require('./fileset')

# ------- Application Class

class Application
  constructor: (name, config, argv) ->
    @argv = argv
    @name = name

    # apply defaults if any
    if (config.use)
      try
        defaults = require('config/' + config.use)
      catch err
        Log.errorAndExit "Invalid 'base' value provided: " + config.base
      # create updated config mapping by merging with default values
      config = Utils.extend defaults, config

    # basic app settings and objects
    @jobs     = {}
    @files    = {}
    @settings = config.settings or {}
    @server   = config.server or {}

    # set root variable, and possibly base route
    unless @settings.root
      # if application name is also a directory in cwd then assume that is root
      if Utils.isDirectory(@name)
        @settings.root = @name
        @server.base or= "/#{@name}"
      # otherwise just work from top level directory
      else
        @settings.root = "/"
        @server.base or= "/"

    # configure static routes with base root and route values
    for route, value of config.server?.static
      @server.static.push
        url  : @applyBase(route)
        path : @applyRoot(value)

    # configure jobs
    for jobname, value of config when jobname in ['build','test','clean','deploy']
      job = new Job(@, jobname, value)
      @jobs[jobname] = job if job.tasks.length > 0

    # configure file sets
    for name, value of config.files
        @files.push new FileSet(@, name, value)

  # ---- Find matching routes/url

  isMatchingUrl: (route) ->
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
      if Utils.startsWith(value, "." + separator)
        value
      else
        Utils.cleanPath(@settings.root, value)
    # return results the same as what was passed in
    if returnArray then values else values[0]

  applyBase: (values...) ->
    values.unshift(@base) if @base
    Utils.cleanRoute.apply(Utils, values)

# ------- Public Functions

module.exports.create = (name, config, argv) ->
  return new Application(name, config, argv)



