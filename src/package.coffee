fs         = require('fs')
path       = require('path')
uglifyjs   = require('uglify-js')
uglifycss  = require('uglifycss')
Dependency = require('./dependency')
Stitch     = require('./stitch')
utils      = require('./utils')
versioning = require('./versioning')

# ------- Parent Classes

class Application
  constructor: (name, config = {}) ->
    @name  = name
    @route = config.route
    @root  = config.root

    # apply defaults
    if (config.defaults)
      try
        loadedDefaults = utils.loadAsset('defaults/' + config.defaults)
        # make sure we don't modify the original assets (which is cached by require)
        defaults = utils.extend({}, loadedDefaults)
      catch err
        utils.error "ERROR: Invalid 'defaults' value provided: " + config.defaults
        process.exit 1
      config = utils.extend(defaults, config)

    # set root variable
    unless @root
      # if name is also directory assume that is root
      if utils.isDirectory(@name)
        @root    = @name
        @route or= @applyBaseRoute("/#{@name}")
      # otherwise just work from top level directory
      else
        @root = ""

    # make sure route has a value
    @route  or= @applyBaseRoute("/")
    @route    = @applyBaseRoute(config.hem?.baseAppRoute, @route)
    @static   = {}
    @packages = {}

    # configure static routes
    for route, value of config.static
      @static[@applyBaseRoute(@route, route)] = @applyRootDir(value)[0]

    # configure js/css/test packages
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
        pkg = new packager(@, value)
        @packages[pkg.name] = pkg

    # configure test structure
    if config.test
      config.test.name = "test"
      @packages.test = new TestPackage(@, config.test)

    # configure versioning
    if config.version
      verType = versioning[config.version.type]
      unless verType
        utils.errorAndExit "Incorrect type value for version configuration: (#{config.version.type})"
      @versioning = new verType(@, config.version)

  isMatchingRoute: (route) ->
    # strip out any versioning applied to file
    if @versioning
      route = @versioning.trim(route)
    # compare against package route values
    for name, pkg of @packages
      return pkg if route is pkg.route
    # return nothing
    return

  unlink: ->
    utils.log("Removing application targets: <green>#{@name}</green>")
    pkg.unlink() for key, pkg of @packages

  build: ->
    utils.log("Building application targets: <green>#{@name}</green>")
    pkg.build() for key, pkg of @packages

  watch: ->
    utils.log("Watching application: <green>#{@name}</green>")
    dirs = (pkg.watch() for key, pkg of @packages)
    # make sure dirs has valid values
    if dirs.length 
      utils.info("- Watching directories: <yellow>#{dirs}</yellow>")
    else
      utils.info("- No directories to watch...")


  version: ->
    utils.log("Versioning application: <green>#{@name}</green>")
    if @versioning
      @versioning.update()
    else 
      utils.errorAndExit "ERROR: Versioning not enabled in slug.json"

  applyRootDir: (value) ->
    values = utils.toArray(value)
    values = values.map (value) =>
      if utils.startsWith(value, "." + path.sep)
        value
      else
        utils.cleanPath(@root, value)
    values

  applyBaseRoute: (values...) ->
    utils.cleanRoute.apply(utils, values)

class Package

  constructor: (parent, config) ->
    @parent = parent
    @name   = config.name
    @paths  = @parent.applyRootDir(config.paths or "")
    @target = @parent.applyRootDir(config.target or "")[0]

    # determine target filename
    if utils.isDirectory(@target)
      # determine actual file name
      if @name is @ext
        targetFile = parent.name
      else
        targetFile = @name
      @target = utils.cleanPath(@target, targetFile)

    # make sure correct extension is present
    unless utils.endsWith(@target, ".#{@ext}")
      @target = "#{@target}.#{@ext}"

    # determine url
    if config.route
      if utils.startsWith(@target,"/")
        @route = config.route
      else
        @route = @parent.applyBaseRoute(parent.route, config.route)
    else
      # use the static urls to determine the package @route
      for route, value of @parent.static when not @route
        if utils.startsWith(@target, value)
          regexp = new RegExp("^#{value.replace(/\\/g,"\\\\")}(\\\\|\/)?")
          targetUrl = @target.replace(regexp,"")
          @route = @parent.applyBaseRoute(route, targetUrl)

    # make sure we have a route to use when using server command
    if utils.COMMAND is "server"
      utils.errorAndExit("Unable to determine route for <yellow>#{@target}</yellow>") unless @route

  handleCompileError: (ex) ->
    # TODO: construct better error message...
    # TOTO: having some problems with sty here, hmmm....
    utils.error(ex.message)
    utils.error(ex.path) if ex.path
    # only return when in server/watch mode, otherwise exit
    switch utils.COMMAND
      when "server" or "watch" then return "console.log(\"HEM compile ERROR: #{ex}\n#{ex.path}\");"
      else process.exit(1)

  unlink: ->
    if fs.existsSync(@target)
      utils.info "- removing <yellow>#{@target}</yellow>"
      fs.unlinkSync(@target) 

  build: (write = true) ->
    extra = (utils.COMPRESS and " <b>--using compression</b>") or ""
    utils.log("- Building target: <yellow>#{@target}</yellow>#{extra}")
    source = @compile()
    if source and write
      dirname = path.dirname(@target)
      unless fs.existsSync(dirname)
        require('mkdirp').sync(dirname)
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
      require('watch').watchTree dir, watchOptions,  (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          @build()
    dirs

  getWatchedDirs: ->
    return @paths

  ext: ""

# ------- Child Classes

class JsPackage extends Package

  constructor: (parent, config)  ->
    # call parent
    super(parent, config)
    
    # javascript only configurations
    @identifier = config.identifier or 'require'
    @libs       = @parent.applyRootDir(config.libs or [])
    @after      = utils.arrayToString(config.after or "")
    @modules    = utils.toArray(config.modules or [])

  compile: ->
    try
      result = [@compileLibs(), @compileModules(), @after].join("\n")
      result = uglifyjs(result) if utils.COMPRESS
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
    _stitch   = new Stitch(@paths)
    _modules  = @depend.resolve().concat(_stitch.resolve())
    if _modules
      _template = utils.loadAsset('stitch')
      _template(identifier: @identifier, modules: _modules)
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
    @paths.concat @libs

  ext: "js"

class TestPackage extends JsPackage

    constructor: (parent, config)  ->
      super(parent, config)
      # TODO: use after in default spine json to setup specs...
      # TODO: testLibs = ['jasmine'] or ['test/public/lib']
      @depends = utils.toArray(config.depends)
      @runner  = config.runner

class CssPackage extends Package

  constructor: (parent, config) ->
    super(parent, config)

  compile: () ->
    try 
      output = []

      # helper function to perform compiles
      requireCss = (filepath) ->
        filepath = require.resolve(path.resolve(filepath))
        delete require.cache[filepath]
        require(filepath)

      # loop over path values
      for fileOrDir in @paths
        # if directory loop over all top level files only
        if utils.isDirectory(fileOrDir)
          for file in fs.readdirSync(fileOrDir) when require.extensions[path.extname(file)]
            file = path.resolve(fileOrDir, file)
            output.push requireCss(file)
        else
          output.push requireCss(fileOrDir)

      # join and minify 
      result = output.join("\n")
      result = uglifycss.processString(result) if utils.COMPRESS
      result
    catch ex
      @handleCompileError(ex)

  ext: "css"

# ------- Public Functions

createApplication = (name, config) ->
  return new Application(name, config)

module.exports.createApplication = createApplication

  
