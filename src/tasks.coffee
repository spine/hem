utils = require('./utils')
fs    = require('fs-extra')
path  = require('path')

# ------- TaskWrapper Class

class TaskWrapper

  # ------- class variables/functions

  @createTask = (app, key, config) ->
    # determine task type
    type = config.type or path.extname(key)
    if Array.isArray(type)
      type = type[type.length - 1]

    # make sure config has the key/type values
    config.type or= type
    config.name or= key

    # construct new task
    if @tasks[type]
      return new @tasks[type](app, config)
    else
      throw new Error("Invalid task name: #{key}")

  # ------- instance functions

  constructor: (app, config) ->
    @app     = app
    @name    = value.name
    @type    = value.type
    @src     or= @app.applyRoot(config.src or [])
    @libs    or= @app.applyRoot(config.libs or [])
    @target  or= @app.applyRoot(config.target or "")[0]
    @bundle  or= config.bundle or config.commonjs

    # determine target filename if task bundles everything into one file
    if @bundle
      if utils.isDirectory(@target)
        # determine actual file name
        if @name is @type
          targetFile = @app.name
        else
          targetFile = @name
        @target = utils.cleanPath(@target, targetFile)
      # make sure correct extension is present
      unless utils.endsWith(@target, ".#{@type}")
        @target = "#{@target}.#{@type}"

    # determine url from configuration
    if config.route
      if utils.startsWith(@target,"/")
        @route = config.route
      else
        @route = @app.applyRoute(config.route)
    # use the static app urls to determine the task @route
    else
      for route in @app.static when not @route
        if utils.startsWith(@target, route.path)
          regexp    = new RegExp("^#{route.path.replace(/\\/g,"\\\\")}(\\\\|\/)?")
          targetUrl = @target.replace(regexp,"")
          @route    = utils.cleanRoute(route.url, targetUrl)

    # make sure we have a defined route value when using server command
    if _argv.command is "server" and not @route
      log.errorAndExit("Unable to determine route for <yellow>#{@target}</yellow>")

  unlink: ->
    # TODO: someday target could be a directory or multiple files...
    if fs.existsSync(@target)
      log.info "- removing <yellow>#{@target}</yellow>"
      fs.unlinkSync(@target)

  watch: ->
    watchOptions = { persistent: true, interval: 1000, ignoreDotFiles: true }
    # get dirs to watch
    dirs = []
    for fileOrDir in @getWatchedDirs()
      continue unless fs.existsSync(fileOrDir)
      if utils.isDirectory(fileOrDir)
        dirs.push fileOrDir
      else
        dirs.push path.dirname(fileOrDir)
    dirs = utils.removeDuplicateValues(dirs)
    # start watch process
    for dir in dirs
      require('watch').watchTree dir, watchOptions, (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          # peform recompile
          @execute(file)
          # emit watch event
          events.emit("watch", @app, @, file)
    # return dirs that are watched
    dirs

  getWatchedDirs: ->
    return @src.concat @libs

  handleTaskError: (ex, exit = false) ->
    # TODO: construct better error message, one that works for all precompilers,
    log.error(ex.message)
    log.error(ex.path) if ex.path
    process.exit(1) if exit

# ------- Available Tasks

Task.tasks = {}
  js  : JsTask
  css : CssTask

# TODO: add image copy and manifest tasks at some point, jslint, component.io build tasks?

# ------- Public Export

module.exports = TaskWrapper


