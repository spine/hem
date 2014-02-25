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

# make sure clean still works
# make sure server still works!
# make sure version still works!
# make sure test still works!
# implement html5 manafest task and jshint tasks
# live reload!!

# ------- Job Class

class Job

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
      # additional logging from custom errors
      Log.error "During execution of <yellow>#{task.name}</yellow> task in (#{@app.name} > #{@name})"
      if ex.name is "CompileError"
        Log "       Mess: #{ex.message}"
        Log "       Path: #{ex.path}"
      else
        Log "  #{ex.stack}"
      # add to results if present
      if task.result
        results.push task.result
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
        callback ex

    # write task results to file system
    @write(results)

    # pass back the results to calling application, in the case
    # of a single task running, just return a result object, otherwise
    # return the results array from all the different tasks
    if id
      if results.length is 1 then results[0] else results
    else
      results

  # format is { target:, source:, route: }
  write: (results) ->

    # helper function
    writeFile = (item) =>
      # make sure we have something to write
      return unless item.target and item.source

      # compress results
      ext = path.extname(item.target)[1..].toLowerCase()
      if @app.argv.compress and @minify[ext]
        item.source = @minify[ext](item.source)

      # return results if in server mode, no writing
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
    for task in @tasks
      watched = task.watch or task.src
      continue unless watched

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
    # create target value
    if task.target
      task.target = @app.applyRoot(task.target)
      task.target = Utils.tmplStr(task.target, task)

    # update src values
    if task.src
      task.src = @app.createPaths(task.src)

    # setup watch list, should be same as task.src in most cases
    if task.watch
      task.watch = @app.createPaths(task.watch)

    # configure target and route values
    @initRoutes(task)

  initRoutes: (task) ->
    # if route already set then see if we need to apply app root
    if @route
      unless Utils.startsWith(@route,"/")
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

# ------- TaskWrapper Class

class TaskWrapper

  # ------- instance functions

  constructor: (job, config) ->
    @job  = job
    @name = config.task
    @app  = job.app


    # copy other config values
    for key, value of config
      @[key] = value unless key in ['job', 'id', 'name', 'task', 'run', 'app']

    # create task function to run
    @task = Job.tasks[config.task].call?(@)
    unless typeof @task is 'function'
      Log.errorAndExit "The job <yellow>#{@job.name}</yellow> task <blue>#{@name}</blue> is invalid."

    # initialize values with init call
    @job.init(@)

    # make sure we have a defined route value when using server command
    if @app.argv.command is "server" and not @route
      Log.errorAndExit("Unable to determine server route for <yellow>#{@target}</yellow>")

  run: (callback, params) ->
    if typeof @task is "function"
      @task.call(@, callback, params)
    else
      Log.errorAndExit "In job '#{@job.name} the task '#{@name}' needs to be a function."

# ------- Add tasks to Job class

Job.tasks = Utils.requireDirectory "#{__dirname}/tasks"

# ------- Public Export

module.exports = Job
