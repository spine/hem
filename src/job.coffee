fs     = require('fs-extra')
path   = require('path')
Utils  = require('./utils')
Events = require('./events')
Log    = require('./log')

# TODO:
# implement node-glob
# implement new watch
# implement (err, result) -> call back for tasks instead of options

# make sure server still works!
# make sure version still works!
# make sure testing still works!
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
        if Utils.isDirectory(fileOrDir)
          dirs.push fileOrDir
        else
          dirs.push path.dirname(fileOrDir)
      dirs = Utils.removeDuplicateValues(dirs)
      # callback that wraps task object in correct scope
      # TODO: have task simply hook into event system instead of passing options!
      callback = (task) ->
        return (file, curr, prev) =>
          if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
            task.run(watch: file)
            Events.emit("watch", task, file)
      # start watch process TODO: triggered when all config loading is done?
      for dir in dirs
        require('watch').watchTree dir, options, callback

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
          @route = Utils.cleanRoute(sroute.url, targetUrl)

# ------- TaskWrapper Class

class TaskWrapper

  # ------- instance functions

  constructor: (job, config) ->
    @job  = job
    @name = config.task

    # copy other config values
    for key, value of config
      @[key] = value unless key in ['job', 'name', 'task', 'argv']

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
    if typeof @task is "function"
      @task.call(@, params)
    else
      Log.errorAndExit "In job '#{@job.name} the task '#{@name}' needs to be a function."

  argv: -> @job.app.argv

  handleError: (ex) ->
    Log.error("(#{@job.name}/#{@name}) - #{ex.message}")
    Log.error(ex.path) if ex.path
    console.log ex.stack if ex.stack
    process.exit(1) unless @argv.watch

  write: (source, filename = @target) ->
    source if @argv().command is "server"

    # helper function
    writeFile = (file, data) ->
      dirname = path.dirname(file)
      fs.mkdirsSync(dirname) unless fs.existsSync(dirname)
      fs.writeFileSync(filename, source)

    # determine if we need to write to filesystem
    if Array.isArray(source)
      # TODO: eventually need logic to determine @target for source when array..
      writeFile(module.filename, module.source) for module in source
    else
      writeFile(filename, source)
    source


# ------- Public Export

module.exports = Job


