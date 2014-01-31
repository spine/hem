fs     = require('fs-extra')
path   = require('path')
utils  = require('./utils')
events = require('./events')
Log    = require('./log')

# ------- Job Class

class Job

  # ------- Available Built in Tasks

  @tasks =
    js      : require('./tasks/js')
    css     : require('./tasks/css')
    version : require('./tasks/version')
    phantom : require('./tasks/phantom')
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

    # start watch if argv supplied
    if @app.argv.watch
      @watch() unless @app.argv.command not in ['clean', 'deploy']

  createTask: (config) ->
    # make sure the 'run' property is set
    unless config.task
      Log.errorAndExit "Missing task value for job #{@name}"

    # construct new taskwrapper instance
    if Job.tasks[config.task]
      return new TaskWrapper(@, config)
    else
      Log.errorAndExit "Cannot find task <blue>#{config.task}</blue> for job <yellow>#{@name}</yellow>"

  run: (params = {}, jobId) ->
    Log "#{@sname} application: <green>#{@app.name}</green>"
    for task in @tasks
      if jobId
        task.run(params) if jobId in [task.name, task.id]
      else
        task.run(params)

  watch: ->
    # TODO: replace watch with new watch npm module...
    options = { persistent: true, interval: 1000, ignoreDotFiles: true }
    dirs    = []
    # create directory list to watch
    for task in @tasks
      for fileOrDir in task.watch
        continue unless fs.existsSync(fileOrDir)
        if utils.isDirectory(fileOrDir)
          dirs.push fileOrDir
        else
          dirs.push path.dirname(fileOrDir)
      dirs = utils.removeDuplicateValues(dirs)
      # callback that wraps task object in correct scope
      callback = (task) ->
        return (file, curr, prev) =>
          if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
            task.run(watch: file)
            events.emit("watch", task, file)
      # start watch process TODO: triggered when all config loading is done?
      for dir in dirs
        require('watch').watchTree dir, options, callback

  # --- Helper methods for task setup

  init: (task) ->
    # update config values
    task.src    = @app.applyRoot(task.src or [])
    task.libs   = @app.applyRoot(task.libs or [])
    task.target = @app.applyRoot(task.target or [], false)

    # setup watch list
    task.watch or= task.src.concat task.libs

    # configure target and route values
    @initTarget(task)
    @initRoutes(task)

  initTarget: (task) ->
    return unless task.target
    # determine target filename if task bundles everything into one file
    if utils.isDirectory(task.target)
      task.target = utils.cleanPath(task.target, @app.name)
    # make sure correct extension is present
    unless task.targetExt and utils.endsWith(task.target, ".#{task.targetExt}")
      task.target = "#{task.target}.#{task.targetExt}"

  initRoutes: (task) ->
    # if route already set then see if we need to apply app root
    if @route
      if utils.startsWith(@target,"/")
        @route = @route
      else
        @route = @app.applyRoute(@route)
    # use the static app urls to determine the task @route
    else
      for sroute in @app.static when not @route
        if utils.startsWith(@target, sroute.path)
          regexp    = new RegExp("^#{sroute.path.replace(/\\/g,"\\\\")}(\\\\|\/)?")
          targetUrl = @target.replace(regexp,"")
          @route = utils.cleanRoute(sroute.url, targetUrl)

# ------- TaskWrapper Class

class TaskWrapper

  # ------- instance functions

  constructor: (job, config) ->
    @job  = job
    @name = config.task

    # copy other config values
    for key, value of config
      @[key] = value unless key in ['job', 'name', 'task']

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
    if @job.app.argv.command is "server" and not @route
      Log.errorAndExit("Unable to determine server route for <yellow>#{@target}</yellow>")

  run: (params = {}) ->
    if @task.run and typeof @task.run is "function"
      @task.call(@, params)
    else
      Log.errorAndExit "Task '#{@name}' does not have a run() method to call."

  handleError: (ex, exit = false) ->
    # TODO: construct better error message, one that works for all precompilers,
    Log.error(ex.message)
    Log.error(ex.path) if ex.path
    process.exit(1) if exit


# TODO: add image copy and manifest tasks at some point, jshint, component.io build tasks?

# ------- Public Export

module.exports = Job


