utils = require('./utils')
fs    = require('fs-extra')
path  = require('path')

# ------- Variables set by hem during startup

_argv = undefined

# ------- Task Classes

class Task
  
  # ------- class variables/functions

  @tasks = {}

  @create = (app, key, value) ->
    # determine task type
    type = value.type or path.extname(key)
    if Array.isArray(type)
      type = type[type.length - 1]

    # make sure config has the key/type values
    value.type or= type
    value.name or= key

    # construct new task
    if @tasks[type]
      return new @tasks[type](app, value)
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
          regexp = new RegExp("^#{route.path.replace(/\\/g,"\\\\")}(\\\\|\/)?")
          targetUrl = @target.replace(regexp,"")
          @route = utils.cleanRoute(route.url, targetUrl)

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

  execute: (file) ->

  handleExecuteError: (ex) ->
    # check for method on _hem to allow override of behavior
    if _hem.handleCompileError
      _hem.handleCompileError(ex)
      return

    # TODO: construct better error message, one that works for all precompilers,
    log.error(ex.message)
    log.error(ex.path) if ex.path

    # only return when in server/watch mode, otherwise exit
    switch _argv.command
      when "server"
        if @ext is "js"
          return "alert(\"HEM: #{ex}\\n\\n#{ex.path}\");"
        else
          return ""
      when "watch"
        return ""
      else
        process.exit(1)


# ------- Built in Tasks

Task.tasks.css = class CssTask extends Task

  constructor: (app, config) ->
    config.bundle = true
    super(app, config)

  execute: () ->
    try
      output = []

      # helper function to perform compiles
      requireCss = (filepath) ->
        filepath = require.resolve(path.resolve(filepath))
        delete require.cache[filepath]
        require(filepath)

      # TODO: use glob to get set of files...
      # TODO: eventually make similar setup to js compile so we only accept 
      #       the file that changes and cache the others...
      for fileOrDir in @src
        # if directory loop over all top level files only
        if utils.isDirectory(fileOrDir)
          for file in fs.readdirSync(fileOrDir) when require.extensions[path.extname(file)]
            file = path.resolve(fileOrDir, file)
            output.push requireCss(file)
        else
          output.push requireCss(fileOrDir)

      # join and minify
      result = output.join("\n")
      result = uglifycss.processString(result) if _argv.compress
      result
    catch ex
      @handleExecuteError(ex)

Task.tasks.js = class Js extends Task

  constructor: (app, config)  ->
    config.commonjs or= 'required'
    # call parent
    super(app, config)

    # javascript only configurations
    @commonjs = config.commonjs

    # javascript to add before/after the stitch file
    @before   = utils.arrayToString(config.before or "")
    @after    = utils.arrayToString(config.after or "")

    # dependecy on other apps?
    @test     = config.test
    @depends  = utils.toArray(config.depends)

  # remove the files module from Stitch so its recompiled
  execute: (file) ->
    Stitch.clear(file) if file
    # extra logging for debug mode
    extra = (_argv.compress and " <b>--using compression</b>") or ""
    log.info("- Building target: <yellow>#{@target}</yellow>#{extra}")
    # compile source
    source = @compile()
    # determine if we need to write to filesystem
    write = _argv.command isnt "server"
    if source and write
      dirname = path.dirname(@target)
      fs.mkdirsSync(dirname) unless fs.existsSync(dirname)
      fs.writeFileSync(@target, source)
    source

  compile: ->
    try
      result = [@before, @compileLibs(), @compileModules(), @after].join("\n")
      result = uglifyjs.minify(result, {fromString: true}).code if _argv.compress
      result
    catch ex
      @handleExecuteError(ex)

  compileModules: ->
    @stitch or= new Stitch(@src)
    @depend or= new Dependency(@modules)
    _modules  = @depend.resolve().concat(@stitch.resolve())
    if _modules
      Stitch.template(@commonjs, _modules)
    else
      ""

  compileLibs: (files = @libs, parentDir = "") ->

    # TODO: need to perform similar operation as stitch in that only
    # compilable code is used... refactor Stitch class to handle this?? except
    # we don't want the code actually stitched in a template, just plain old js

    # check if folder or file
    results = []
    for file in files
      slash = if parentDir is "" then "" else path.sep
      file  = parentDir + slash + file
      if fs.existsSync(file)
        stats = fs.lstatSync(file)
        if (stats.isDirectory())
          dir = fs.readdirSync(file)
          results.push @compileLibs(dir, file)
        else if stats.isFile() and path.extname(file) in ['.js','.coffee']
          results.push fs.readFileSync(file, 'utf8')
    results.join("\n")

  ext: "js"

# TODO: add image copy and manifest tasks at some point, jslink task??
# TODO: different tasks, build -> build/watch/server, test -> build/test runner
#       need to pass last build results to next task?? Or perhaps keep task output in
#       a temp variable and allow other tasks to manipulate them? only write to file 
#       system once all tasks are complete???
# TODO: add additional events that are triggered, perhaps on compile to edit source??
# TODO: write helper method for using node-glob that takes array/async... sets root
# TODO: add generic task that users can fill in their own command... or perhaps add event 
#       handlers in config file, beforeBuild, afterBuild
# TODO: give tasks name so they can be references in event handlers?

# ------- Public Export

module.exports = Task


