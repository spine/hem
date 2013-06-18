fs         = require('fs')
path       = require('path')
uglify     = require('uglify-js')
stitchFile = require('../assets/stitch')
Dependency = require('./dependency')
Stitch     = require('./stitch')
utils      = require('./utils')
versions   = require('./versioning')

# ------- Parent Classes

class Application
  constructor: (name, config = {}) ->
    @name  = name

    # apply defaults
    if (config.defaults)
      try
        defaults = require('../assets/defaults/' + config.defaults)
      catch err
        console.error "ERROR: Invalid 'defaults' value provided: " + config.defaults
        process.exit 1
      utils.log("Applying '" + config.defaults + "' defaults to configuration..." if global.ARGV?.v)
      config = utils.extend(defaults, config)

    # set variables
    @root  = config.root or ""
    @route = config.route or  "/"

    # create packages
    @packages = []
    @static   = {}
    
    # configure static routes
    for route, value of config.static
      @static[utils.cleanRoute(@route, route)] = value

    # configure js/css/test packages
    if config.js
      @js   = new JsPackage(@,config.js)
      @packages.push @js
    if config.css
      @css  = new CssPackage(@,config.css)
      @packages.push @css
    if config.test
      @test = new JsPackage(@,config.test)
      @packages.push @test

    # configure versioning
    @versioning = config.version or undefined
    if @versioning
      @versioning.type or= "package"
      @versioning.module = versions[@versioning.type]
      if not (@versioning.module)
        utils.errorAndExit "Incorrect type value for versioning (#{@versioning.type})"


  isMatchingRoute: (route) ->
    # strip out any versioning applied to file
    if @versioning
      route = @versioning.module.trimVersion(route)
    # compare against package route values
    for pkg in @packages
      return pkg if route is pkg.route
    # return nothing
    return

  unlink: ->
    pkg.unlink() for pkg in @packages

  build: ->
    utils.log("Building application: <green>#{@name}</green>")
    pkg.build() for pkg in @packages

  watch: ->
    utils.log("Watching application: <green>#{@name}</green>")
    pkg.watch() for pkg in @packages

  version: ->
    utils.log("Versioning application: <green>#{@name}</green>")
    if @versioning
      @versioning.module.updateVersion(@)
    else 
      utils.errorAndExit "ERROR: Versioning not enabled in slug.json"

class Package
  constructor: (parent, config = {}) ->
    @parent = parent
    @paths  = utils.toArray(config.paths or [])

    # determine target filename
    if @parent.root.length > 0
      @target = utils.cleanPath(parent.root, config.target)
    else
      @target = config.target

    # determine url
    if config.route
      if utils.startsWith(@target,"/")
        @route = config.route
      else
        @route = utils.cleanRoute(parent.route, config.route)
    else
      # use the static urls to determine the package @route
      for route, value of @parent.static when not @route
        if utils.startsWith(@target, value)
          regexp = new RegExp("^#{value}")
          targetUrl = @target.replace(regexp,"")
          @route = utils.cleanRoute(route, targetUrl)
    # make sure we have a route to use 
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
    fs.unlinkSync(@target) if fs.existsSync(@target)

  build: (save = false)  ->
    extra = (utils.COMPRESS and " <b>--using compression</b>") or ""
    utils.log("- Building target: <yellow>#{@target}</yellow>#{extra}")
    source = @compile()
    fs.writeFileSync(@target, source) if source and save
    source
    
  watch: ->
    for dir in @getWatchedDirs()
      continue unless fs.existsSync(dir)
      require('watch').watchTree dir, { persistent: true, interval: 1000 },  (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          @build()

  getWatchedDirs: ->
    return @paths

# ------- Child Classes

class JsPackage extends Package

  constructor: (parent, config = {}) ->
    config.target or= parent.name + ".js"
    super(parent, config)
    
    # javascript only configurations
    @identifier = config.identifier or 'require'
    @libs       = utils.toArray(config.libs or [])
    @modules    = utils.toArray(config.modules or [])
    @after      = utils.toArray(config.after or [])

    # for testing types
    # TODO: or have test libs to pull test files from? woulnd't need after stuff if we did that??
    # TODO: testLibs = ['jasmine'] or ['test/public/lib']
    @testType   = config.test or undefined

  compile: ->
    try
      result = [@compileLibs(), @compileModules(), @compileLibs(@after)].join("\n")
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
    stitchFile(identifier: @identifier, modules: _modules)

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
    @paths.concat @libs.concat @after

class CssPackage extends Package

  constructor: (parent, config = {}) ->
    config.target or= parent.name + ".css"
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

# ------- Public Functions

createApplication = (name, config) ->
  return new Application(name, config)

module.exports.createApplication = createApplication

  
