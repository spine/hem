fs     = require('fs-extra')
gaze   = require('gaze')
path   = require('path')
Utils  = require('./utils')
Events = require('./events')
Log    = require('./log')
Stitch = require('./stitch')
# minify helpers
uglifyjs  = require('uglify-js')
uglifycss = require('uglifycss')

# TODO:

# implement node-glob
# implement new watch

# implement (err, result) -> call back for tasks instead of options
# call write once all tasks complete, use values in result to save { js: [{ path, route, source }] }
# move handle error to job runner, from callback

# make sure server still works!
# make sure version still works!
# make sure test still works!
# implement html5 manafest task and jshint tasks
# live reload!!

# ------- Job Class

class Job

  # ------- Available Built in Tasks

  @tasks =
    js      : require('./tasks/js')
    css     : require('./tasks/css')
    version : require('./tasks/version')
    phantom : require('./tasks/phantom')
    browser : require('./tasks/browser')
    clean   : require('./tasks/clean')

  # ------- instance functions

  constructor: (app, name, config) ->
    @app   = app
    @name  = name
    @sname = name.charAt(0).toUpperCase() + name.slice(1)
    @tasks = []

    # function to help create tasks and push to job array
    taskHelper = (taskConfig) =>
      task = @createTask(taskConfig)
      task.id = @tasks.length
      @tasks.push(task)

    # configure tasks
    if Array.isArray config
      taskHelper(tconfig) for tconfig in config
    else if config
      taskHelper(config)

  createTask: (config) ->
    # make sure the 'run' property is set
    unless config.task
      Log.errorAndExit "Missing task value for job #{@name}"

    # construct new taskwrapper instance
    if Job.tasks[config.task]
      return new TaskWrapper(@, config)
    else
      Log.errorAndExit "Cannot find task <blue>#{config.task}</blue> for job <yellow>#{@name}</yellow>"

  run: (id, params = {}) ->
    # log the fun that is about to begin
    watch = @app.argv.watch and '<b>(and watch)</b> ' or ''
    Log "#{@sname} #{watch}application: <green>#{@app.name}</green>"

    # capture results
    results = []

    # error handler
    handleError = (task, ex) =>
      Log.error("(#{@app.name} > #{@name} > #{task.name}) #{ex.message}")
      # additional logging from custom errors
      Log ("       Path: #{ex.path}") if ex.path
      # add to results
      if err.result
        results.push err.result
      # exit if not in watch mode
      process.exit(1) unless @app.argv.watch

    # run tasks
    for task in @tasks when !id or task.id is id
      # create callback with correct scope for task
      callback = do (task) ->
        return (err, result) ->
          if err
            handleError(task, err)
          else
            results.push result if result

      # call task
      try
        task.run callback, params
      catch ex
        callback err

    # write task results to file system 
    @write(results)
    # pass back the results to calling application, in the case
    # of a single task running, just return a result object, otherwise
    # return the results array from all the different tasks
    if id 
      if results.length is 1 then results[0] else results
    else
      results

  write: (results) ->

    # helper function
    writeFile = (item) =>
      # make sure we have something to write
      return unless item.target and item.source

      # compress results
      ext = path.extname(item.target)[1..].toLowerCase()
      if @app.argv.compress and @minify[ext]
        item.source = @minify[ext](item.source)

      #  return results if in server mode, no writing
      return if @app.argv.command is "server"

      # make sure directory exists
      dirname = path.dirname(item.target)
      fs.mkdirsSync(dirname) unless fs.existsSync(dirname)

      # write to file system
      fs.writeFileSync(target, item.source)

    # loop over the results array values
    for result in results
      if Array.isArray result
        for item in result when typeof item is "object"
          writeFile(item)
      else if typeof result is "object"
        writeFile(result)

  minify:
    js: (source) ->
      uglifyjs.minify(source, {fromString: true}).code
    css: (source) ->
      uglifycss.processString(source)

  watch: ->
    # create directory list to watch
    for task in @tasks when task.watch?.length > 0
      # create callback
      callback = do (task) ->
        return (event, filepath) ->
          task.job.run task.id, watch: filepath
          Events.emit "watch", task, event, filepath

      # start watch
      gaze task.watch, (err, watcher) ->
        Log.errorAndExit err if err
        watcher.on 'all', (event, filepath) ->
          callback(event, filepath)


  # --- Helper methods for task setup

  init: (task) ->
    # update config values
    task.src    = @app.applyRoot(task.src or [])
    task.lib    = @app.applyRoot(task.lib or [])
    task.target = @app.applyRoot(task.target or [], false)

    # setup watch list
    if task.watch
      task.watch = @app.applyRoot(task.watch or [])
    else if task.src?.length > 0 or task.lib?.length > 0
      task.watch or= task.src.concat task.lib

    # configure target and route values
    @initTarget(task)
    @initRoutes(task)

  initTarget: (task) ->
    return unless task.target
    # determine target filename if task bundles everything into one file
    if Utils.isDirectory(task.target)
      task.target = Utils.cleanPath(task.target, @app.name)
    # make sure correct extension is present
    unless task.targetExt and Utils.endsWith(task.target, ".#{task.targetExt}")
      task.target = "#{task.target}.#{task.targetExt}"

  initRoutes: (task) ->
    # if route already set then see if we need to apply app root
    if @route
      if Utils.startsWith(@target,"/")
        @route = @route
      else
        @route = @app.applyRoute(@route)
    # use the static app urls to determine the task @route
    else
      for sroute in @app.static when not @route
        if Utils.startsWith(@target, sroute.path)
          regexp    = new RegExp("^#{sroute.path.replace(/\\/g,"\\\\")}(\\\\|\/)?")
          targetUrl = @target.replace(regexp,"")
          # TODO: make a regex, somehow need to incoperate/register an additional
          # regex helper if there is a deploy/version task
          @route = Utils.cleanRoute(sroute.url, targetUrl)

  applyTargetAndRoutes: (results) ->


# ------- TaskWrapper Class

class TaskWrapper

  # ------- instance functions

  constructor: (job, config) ->
    @job  = job
    @name = config.task

    # copy other config values
    for key, value of config
      @[key] = value unless key in ['job', 'id', 'name', 'task', 'argv', 'run', 'app']

    # create task function to run
    @task = Job.tasks[config.task].call?(@)
    unless typeof @task is 'function'
      Log.errorAndExit "The job <yellow>#{@job.name}</yellow> task <blue>#{@name}</blue> is invalid."

    # initialize values with init call
    if @init is undefined
      @job.init(@)
    else
      @init?()

    # make sure we have a defined route value when using server command
    if @argv().command is "server" and not @route
      Log.errorAndExit("Unable to determine server route for <yellow>#{@target}</yellow>")

  run: (callback, params) ->
    if typeof @task is "function"
      @task.call(@, callback, params)
    else
      Log.errorAndExit "In job '#{@job.name} the task '#{@name}' needs to be a function."

  # helper access methods

  argv: -> @job.app.argv
  app:  -> @job.app


# ------- Public Export

module.exports = Job


