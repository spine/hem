fs         = require('fs-extra')
path       = require('path')
uglifyjs   = require('uglify-js')
uglifycss  = require('uglifycss')
Dependency = require('./dependency')
Stitch     = require('./stitch')
utils      = require('./utils')
events     = require('./events')
log        = require('./log')
versioning = require('./versioning')

# ------- Variables set by hem during startup

_hem  = undefined
_argv = undefined

# ------- Application Class

class Application
  constructor: (name, config = {}) ->
    @name  = name
    @route = config.route
    @root  = config.root

    # apply defaults
    if (config.defaults)
      try
        # make sure we don't modify the original assets (which is cached by require)
        loadedDefaults = utils.loadAsset('defaults/' + config.defaults)
        defaults = utils.extend({}, loadedDefaults)
      catch err
        log.error "ERROR: Invalid 'defaults' value provided: " + config.defaults
        process.exit 1
      # create updated config mapping by merging with default values
      config = utils.extend(defaults, config)

    # set root variable
    unless @root
      # if application name is also a directory then assume that is root
      if utils.isDirectory(@name)
        @root    = @name
        @route or= "/#{@name}"
      # otherwise just work from top level directory
      else
        @root    = "/"
        @route or= "/"

    # make sure route has a value
    @static   = []
    @packages = []

    # configure static routes with base root and route values
    for route, value of config.static
      @static.push
        url  : @applyBaseRoute(route)
        path : @applyRootDir(value)[0]

    # configure js/css packages
    for key, value of config
      packager = undefined
      # determine package type
      if key is 'js' or utils.endsWith(key,'.js')
        packager = JsPackage
        value.name = key
      else if key is 'css' or utils.endsWith(key,'.css')
        packager = CssPackage
        value.name = key
      # add to @packages array
      if packager
        @packages.push(new packager(@, value))

    # configure test structure
    if config.test
      config.test.name = "test"
      @packages.push(new TestPackage(@, config.test))

    # configure versioning
    if config.version
      verType = versioning[config.version.type]
      unless verType
        log.errorAndExit "Incorrect type value for version configuration: (#{config.version.type})"
      @versioning = new verType(@, config.version)

  getTestPackage: ->
    for pkg in @packages
      return pkg if pkg.constructor.name is "TestPackage"

  isMatchingRoute: (route) ->
    # strip out any versioning applied to file
    if @versioning
      route = @versioning.trim(route)
    # compare against package route values
    for pkg in @packages
      return pkg if route is pkg.route.toLowerCase()
    # return nothing
    return

  unlink: ->
    log("Removing application: <green>#{@name}</green>")
    pkg.unlink() for pkg in @packages

  build: ->
    log("Building application: <green>#{@name}</green>")
    pkg.build() for pkg in @packages

  watch: ->
    log("Watching application: <green>#{@name}</green>")
    dirs = (pkg.watch() for pkg in @packages)
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

  applyRootDir: (value) ->
    # TODO: eventually use the Hem.home directory value if the home
    # TODO: value is different from the process.cwd() value?!
    values = utils.toArray(value)
    values = values.map (value) =>
      if utils.startsWith(value, "." + path.sep)
        value
      else
        utils.cleanPath(@root, value)
    values

  applyBaseRoute: (values...) ->
    values.unshift(@route) if @route
    utils.cleanRoute.apply(utils, values)

# ------- Package Classes

class Package

  constructor: (app, config) ->
    @app    = app
    @name   = config.name
    @src    = @app.applyRootDir(config.src or "")
    @target = @app.applyRootDir(config.target or "")[0]

    # determine target filename
    if utils.isDirectory(@target)
      # determine actual file name
      if @name is @ext
        targetFile = @app.name
      else
        targetFile = @name
      @target = utils.cleanPath(@target, targetFile)
    # make sure correct extension is present
    unless utils.endsWith(@target, ".#{@ext}")
      @target = "#{@target}.#{@ext}"

    # determine url from configuration
    if config.route
      if utils.startsWith(@target,"/")
        @route = config.route
      else
        @route = @app.applyBaseRoute(config.route)
    # use the static urls to determine the package @route
    else
      for route in @app.static when not @route
        if utils.startsWith(@target, route.path)
          regexp = new RegExp("^#{route.path.replace(/\\/g,"\\\\")}(\\\\|\/)?")
          targetUrl = @target.replace(regexp,"")
          @route = utils.cleanRoute(route.url, targetUrl)

    # make sure we have a route to use when using server command
    if _argv.command is "server" and not @route
      log.errorAndExit("Unable to determine route for <yellow>#{@target}</yellow>")

  handleCompileError: (ex) ->
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

  unlink: ->
    if fs.existsSync(@target)
      log.info "- removing <yellow>#{@target}</yellow>"
      fs.unlinkSync(@target)

  build: (file) ->
    # remove the files module from Stitch so its recompiled
    Stitch.clear(file) if file
    # extrea logging
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

  watch: ->
    watchOptions = { persistent: true, interval: 1, ignoreDotFiles: true, maxListeners: 128 }
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
      require('watch').watchTree dir, watchOptions, (f, curr, prev) =>
        if (typeof f is "object" && prev is null and curr is null)
          # Finished walking the tree
          return
        # f was changed
        console.log 'build', f
        @build(f)
        # emit watch event
        events.emit("watch", @app, @, f)
    # return dirs that are watched
    dirs

  getWatchedDirs: ->
    return @src

  ext: ""

# ------- Child Classes

class JsPackage extends Package

  constructor: (app, config)  ->
    # call parent
    super(app, config)

    # javascript only configurations
    @commonjs = config.commonjs or 'require'
    @libs     = @app.applyRootDir(config.libs or [])
    @modules  = utils.toArray(config.modules or [])

    # javascript to add before/after the stitch file
    @before   = utils.arrayToString(config.before or "")
    @after    = utils.arrayToString(config.after or "")

  compile: ->
    try
      result = [@before, @compileLibs(), @compileModules(), @after].join("\n")
      result = uglifyjs.minify(result, {fromString: true}).code if _argv.compress
      result
    catch ex
      @handleCompileError(ex)

  compileModules: ->

    # TODO use detective to load only those modules that are required ("required")?
    # or use the modules [] to specifiy which modules if any to load? or
    # set to false to never load any node_modules even if they are required in
    # javascript files. Would have to determine files needed from the stitched
    # files first...

    # TODO: also for testing we can remove the specs that don't match and optional parameter

    @depend or= new Dependency(@modules)
    @stitch or= new Stitch(@src)
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
      # treat as normal javascript string
      if utils.endsWith(file,";")
        results.join(file)
      # else load as file/dir
      else
        slash = if parentDir is "" then "" else path.sep
        # ignore files that start with "_", used for template files that process
        # includes (ex stylus), so they don't get compiled twice.
        continue if file.startsWith("_")
        # set full path for following code checks
        file  = parentDir + slash + file
        if fs.existsSync(file)
          stats = fs.lstatSync(file)
          if (stats.isDirectory())
            dir = fs.readdirSync(file)
            results.push @compileLibs(dir, file)
          else if stats.isFile() and path.extname(file) in ['.js','.coffee']
            results.push fs.readFileSync(file, 'utf8')
    results.join("\n")

  getWatchedDirs: ->
    @src.concat @libs

  ext: "js"

class TestPackage extends JsPackage

  constructor: (app, config)  ->
    super(app, config)
    # test configurations
    @depends   = utils.toArray(config.depends)

    # get test home directory based on target file location
    @testHome  = path.dirname(@target)
    @framework = _hem.options.hem.test.frameworks

    # test to make sure framework is set correctly
    if @framework not in ['jasmine','mocha']
      log.errorAndExit("Test frameworks value is not valid: #{@framework}")

    # javascript to run at end of specs file
    @after +=
    """
    // HEM: load in specs from test js file
    var onlyMatchingModules = \"#{_argv.grep or ""}\";
    for (var key in #{@commonjs}.modules) {
      if (onlyMatchingModules && key.indexOf(onlyMatchingModules) == -1) {
        continue;
      }
      #{@commonjs}(key);
    }
    """

  build: (file) ->
    @createTestFiles()
    super(file)

  getAllTestTargets: (relative = true) ->
    targets   = []
    homeRoute = path.dirname(@route)

    # create function to determine route/path
    relativeFn = (home, target, url = true) ->
      value = ""
      if relative
        value = path.relative(home, target)
      else
        value = target
      if url
        # deal with windows :o(
        value.replace(/\\/g, "/")
      else
        value

    # first get dependencies
    for dep in @depends
      for depapp in _hem.allApps when depapp.name is dep
        for pkg in depapp.packages
          continue unless pkg.constructor.name is "JsPackage"
          url = relativeFn(homeRoute, pkg.route)
          pth = relativeFn(@testHome, pkg.target)
          targets.push({ url: url, path: pth })

    # get app targets
    for pkg in @app.packages
      continue unless pkg.constructor.name is "JsPackage"
      url = relativeFn(homeRoute, pkg.route)
      pth = relativeFn(@testHome, pkg.target)
      targets.push({ url: url, path: pth })

    # finally add main test target file
    url = relativeFn(homeRoute, pkg.route)
    pth = relativeFn(@testHome, pkg.target)
    targets.push({ url: url, path: pth })
    targets

  getFrameworkFiles: ->
    targets = []
    frameworkPath = path.resolve(__dirname, "../assets/testing/#{@framework}")
    for file in fs.readdirSync(frameworkPath)
      if path.extname(file) in [".js",".css"]
        url = "#{@framework}/#{file}"
        targets.push({ url: url, path: url })
    targets

  getTestIndexFile: ->
    path.resolve(@testHome,'index.html')

  # TODO: only do this for browser tests???

  createTestFiles: ->
    # create index file and libs if they currently don't exist
    indexFile = @getTestIndexFile()
    unless fs.existsSync(indexFile)
      files = []
      files.push.apply(files, @getFrameworkFiles())
      files.push.apply(files, @getAllTestTargets())
      template = utils.tmpl("testing/index", { commonjs: @commonjs, files: files, before: @before } )
      fs.outputFileSync(indexFile, template)

      # copy the framework files if they aren't present
      frameworkPath = path.resolve(__dirname, "../assets/testing/#{@framework}")
      for file in fs.readdirSync(frameworkPath)
        if path.extname(file) in [".js",".css"]
          filepath = path.resolve(@testHome, "#{@framework}/#{file}")
          utils.copyFile(path.resolve(frameworkPath, file), filepath)

class CssPackage extends Package

  constructor: (app, config) ->
    super(app, config)

  compile: () ->
    try
      output = []

      # helper function to perform compiles
      requireCss = (filepath) ->
        filepath = require.resolve(path.resolve(filepath))
        delete require.cache[filepath]
        require(filepath)

      # loop over path values
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
      @handleCompileError(ex)

  ext: "css"

# ------- Public Functions

create = (name, config, hem, argv) ->
  _hem  or= hem
  _argv or= argv
  return new Application(name, config)

module.exports.create = create
