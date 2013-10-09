fs         = require('fs-extra')
path       = require('path')
uglifyjs   = require('uglify-js')
uglifycss  = require('uglifycss')
Dependency = require('./dependency')
Stitch     = require('./stitch')
utils      = require('./utils')
argv       = require('./utils').ARGV
log        = require('./log')
versioning = require('./versioning')


# ------- Application Class

class Application
  constructor: (name, config = {}, hem) ->
    @hem   = hem
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
      return pkg if route is pkg.route
    # return nothing
    return

  unlink: ->
    log("Removing application targets: <green>#{@name}</green>")
    pkg.unlink() for pkg in @packages

  build: ->
    log("Building application targets: <green>#{@name}</green>")
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
    if argv.command is "server" and not @route
      log.errorAndExit("Unable to determine route for <yellow>#{@target}</yellow>")

  handleCompileError: (ex) ->
    # TODO: construct better error message, one that works for all precompilers,
    # having some problems with sty here, hmmm....
    log.error(ex.message)
    log.error(ex.path) if ex.path
    # only return when in server/watch mode, otherwise exit
    switch argv.command
      when "server" or "watch"
        # TODO: only return this for javascript
        return "console.log(\"HEM compile ERROR: #{ex}\n#{ex.path}\");"
      else
        process.exit(1)

  unlink: ->
    if fs.existsSync(@target)
      log.info "- removing <yellow>#{@target}</yellow>"
      fs.unlinkSync(@target)

  build: (write = true) ->
    extra = (argv.compress and " <b>--using compression</b>") or ""
    log("- Building target: <yellow>#{@target}</yellow>#{extra}")
    source = @compile()
    if source and write
      dirname = path.dirname(@target)
      fs.mkdirsSync(dirname) unless fs.existsSync(dirname)
      fs.writeFileSync(@target, source)
    source

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
          @build()
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
    @commonjs   = config.commonjs or 'require'
    @libs       = @app.applyRootDir(config.libs or [])
    @after      = utils.arrayToString(config.after or "")
    @modules    = utils.toArray(config.modules or [])

  compile: ->
    try
      result = [@compileLibs(), @compileModules(), @after].join("\n")
      result = uglifyjs.minify(result, {fromString: true}).code if argv.compress
      result
    catch ex
      @handleCompileError(ex)

  compileModules: ->

    # TODO use detective to load only those modules that are required ("required")?
    # or use the modules [] to specifiy which modules if any to load? or
    # set to false to never load any node_modules even if they are required in
    # javascript files. Would have to determine files needed from the stitched
    # files first...

    @depend or= new Dependency(@modules)
    _stitch   = new Stitch(@src)
    _modules  = @depend.resolve().concat(_stitch.resolve())
    if _modules
      _stitch.template(@commonjs, _modules)
    else
      ""

  compileLibs: (files = @libs, parentDir = "") ->

    # TODO: need to perform similar operation as stitch in that only
    # compilable code is used...

    # check if folder or file
    results = []
    for file in files
      # treat as normal javascript
      if utils.endsWith(file,";")
        results.join(file)
      # else load as file/dir
      else
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

  getWatchedDirs: ->
    @src.concat @libs

  ext: "js"

class TestPackage extends JsPackage

  constructor: (app, config)  ->
    super(app, config)
    # test configurations
    @depends   = utils.toArray(config.depends)
    @runner    = config.runner
    @framework = config.framework

    # get test home directory based on target file location
    @testHome = path.dirname(@target)

  build: ->
    @createTestFiles()
    super()

  getAllTestTargets: ->
    targets = []
    homeRoute = path.dirname(@route)

    # first get dependencies
    for dep in @depends
      for depapp in @app.hem.allApps when depapp.name is dep
        for pkg in depapp.packages
          if pkg.constructor.name is "JsPackage"
            url = path.relative(homeRoute, pkg.route)
            pth = path.relative(@testHome, pkg.target)
            targets.push({ url: url, path: pth })

    # get app targets
    for pkg in @app.packages
      if pkg.constructor.name is "JsPackage"
        url = path.relative(homeRoute, pkg.route)
        pth = path.relative(@testHome, pkg.target)
        targets.push({ url: url, path: pth })

    # finally test file
    url = path.relative(homeRoute, pkg.route)
    pth = path.relative(@testHome, pkg.target)
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

  createTestFiles: ->
    # create index file
    indexFile = @getTestIndexFile()
    files = []
    files.push.apply(files, @getFrameworkFiles())
    files.push.apply(files, @getAllTestTargets())
    template = utils.tmpl("testing/index", { commonjs: @commonjs, files: files } )
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
      result = uglifycss.processString(result) if argv.compress
      result
    catch ex
      @handleCompileError(ex)

  ext: "css"

# ------- Public Functions

createApplication = (name, config, hem) ->
  return new Application(name, config, hem)

module.exports.createApplication = createApplication


