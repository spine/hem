fs         = require('fs')
path       = require('path')
uglify     = require('uglify-js')
Dependency = require('./dependency')
Stitch     = require('./stitch')
utils      = require('./utils')
versions   = require('./versioning')

# ------- Parent Classes

class Application
  constructor: (name, config = {}) ->
    @name  = name
    @route = config.route
    @root  = config.root

    # apply defaults
    if (config.defaults)
      try
        defaults = utils.loadAsset('defaults/' + config.defaults)
      catch err
        console.error "ERROR: Invalid 'defaults' value provided: " + config.defaults
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
    @versioning = config.version or undefined
    if @versioning
      # TODO: move to a consturctor!! <<<<, need to make this an instance of a class!!! <<
      @versioning.type or= "package"
      @versioning.module = versions[@versioning.type]
      # update file paths
      files = utils.toArray(@versioning.files)
      files = files.map (file) =>
        @applyRootDir(file)[0]
      @versioning.files = files
      if not (@versioning.module)
        utils.errorAndExit "Incorrect type value for versioning (#{@versioning.type})"

  isMatchingRoute: (route) ->
    # strip out any versioning applied to file
    if @versioning
      route = @versioning.module.trimVersion(route)
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
    pkg.watch() for key, pkg of @packages

  version: ->
    utils.log("Versioning application: <green>#{@name}</green>")
    if @versioning
      @versioning.module.updateVersion(@)
    else 
      utils.errorAndExit "ERROR: Versioning not enabled in slug.json"

  applyRootDir: (value) ->
    values = utils.toArray(value)
    values = values.map (value) =>
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
          regexp = new RegExp("^#{value}")
          targetUrl = @target.replace(regexp,"")
          @route = @parent.applyBaseRoute(route, targetUrl)

    # make sure we have a route to use when using server command
    if utils.COMMAND is "server"
      utils.errorAndExit("Unable to determine route for <yellow>#{@target}</yellow>") unless @route

  handleCompileError: (ex) ->
    if ex.stack
      utils.log(ex.stack)
    else
      utils.error(ex.message)
    console.error ex.path if ex.path
    console.error ex.location if ex.location
    # only return when in server/watch mode, otherwise exit
    switch utils.COMMAND
      when "server" or "watch" then return "console.log(\"HEM compile ERROR: #{ex}\");"
      else process.exit(1)

  unlink: ->
    if fs.existsSync(@target)
      utils.info "- removing <yellow>#{@target}</yellow>"
      fs.unlinkSync(@target) 

  build: (write = true) ->
    extra = (utils.COMPRESS and " <b>--using compression</b>") or ""
    utils.log("- Building target: <yellow>#{@target}</yellow>#{extra}")
    source = @compile()
    fs.writeFileSync(@target, source) if source and write
    source

  watch: ->
    for dir in @getWatchedDirs()
      continue unless fs.existsSync(dir)
      require('watch').watchTree dir, { persistent: true, interval: 1000 },  (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          @build()

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
    @after      = config.after or ""
    @modules    = utils.toArray(config.modules or [])

  compile: ->
    try
      result = [@compileLibs(), @compileModules(), @after].join("\n")
      result = uglify(result) if utils.COMPRESS
      result
    catch ex
      @handleCompileError(ex)

  compileModules: ->
    # TODO use detective....??
    # TODO cache results since this shouldn't change too much??
    @depend or= new Dependency(@modules)
    _stitch   = new Stitch(@paths)
    _modules  = @depend.resolve().concat(_stitch.resolve())
    if _modules
      _template = utils.loadAsset('stitch')
      _template(identifier: @identifier, modules: _modules)
    else
      ""

  compileLibs: (files = @libs, parentDir = "") ->
    # check if folder or file 
    results = []
    for file in files
      slash = if parentDir is "" then "" else path.sep
      file  = parentDir + slash + file
      if fs.existsSync(file)
        stats = fs.lstatSync(file)
        if (stats.isDirectory())
          # get directory contents
          dir = fs.readdirSync(file)
          results.push @compileLibs(dir, file)
        else if (stats.isFile())
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
      @type   = config.type
      @runner = config.runner

class CssPackage extends Package

  constructor: (parent, config) ->
    super(parent, config)

  compile: () ->
    try 
      result = []
      for _path in @paths
        # TODO: currently this only works with index files, perhaps someday loop 
        # over the directory contents and pickup the other files?? though with 
        # stylus can always get other content by mixins
        _path  = require.resolve(path.resolve(_path))
        delete require.cache[_path]
        result.push require(_path)
      # TODO: do we want a minify option for css or is that built into the compilers??
      result.join("\n")
    catch ex
      @handleCompileError(ex)

  ext: "css"

# ------- Public Functions

createApplication = (name, config) ->
  return new Application(name, config)

module.exports.createApplication = createApplication

  
