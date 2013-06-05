fs         = require('fs')
path       = require('path')
uglify     = require('uglify-js')
stitchFile = require('../assets/stitch')
Dependency = require('./dependency')
Stitch     = require('./stitch')
{toArray}  = require('./utils')

# ------- Public Functions

jsFile  = /\.js$/i
cssFile = /\.css$/i

createPackage = (name, config) ->
  if jsFile.test config.target
    # TODO: at some point merge in framework defaults (ex. spine)
    return new JsPackage(name,config)
  else if cssFile.test config.target
    # TODO: framework defaults for css
    return new CssPackage(name, config)
    # TODO: setup target for package that contains other packages?
  else
    throw new Error("Unsupported package type.")

# ------- Classes

class Package
  constructor: (name, config = {}) ->
    @name   = name
    @target = config.target or throw new Error("Missing target for #{name}")
    @root   = "./"
    @public = "public"
    @paths  = toArray(config.paths or [])
    @test   = config.test

    # determine url
    @url    = config.url or "/" + target

    # determine static folder
    @static = config.static or 
      "/" : "#{root}/public"

    # handle versioning
    @version = config.version

    # TODO: provide framework file to that will supply defaults
    # - merge that with options provided? put merge in utils.coffee copy from connect
    # - if folder starts with ./ then start from slug otherwise use defaults
    # - provide root/context value to set starting point
    # - call framework options by name of framework, hem spine new healthlink

    # javascript only configurations
    @identifier  = config.identifier or 'require'
    @libs        = toArray(config.libs or [])
    @modules     = toArray(config.modules or [])
    @after       = config.after or ""

  handleCompileError: (ex) ->
    console.error ex.message
    console.error ex.path if ex.path
    console.error ex.location if ex.location
    # only return when in server/watch mode, otherwise exit
    switch @argv.command
      when "server" then return "console.log(\"#{ex}\");"
      when "watch"  then return ""
      else process.exit(1)

  unlink: ->
    fs.unlinkSync(@target) if fs.existsSync(@target)

  build: (minify = false) ->
    console.log "Building '#{@name}' target: #{@target}"
    source = @compile(minify)
    fs.writeFileSync(@target, source) if source
    
  watch: ->
    console.log "Watching '#{@name}'"
    for dir in (path.dirname(lib) for lib in @libs).concat @paths
      continue unless fs.existsSync(dir)
      require('watch').watchTree dir, { persistent: true, interval: 1000 },  (file, curr, prev) =>
        @build() if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)

  canTest: ->
    # eventually see if there is /test folder
    return jsFile.test target

  isMatchingUrl: (url) ->
    # TODO: strp out any versioning


# ------- Child Classes

class JsPackage extends Package

  constructor: (name, config = {}) ->
    super(name, config)

  compile: (minify = false) ->
    try
      result = [@compileLibs(), @compileModules(), @after].join("\n")
      result = uglify(result) if minify
      result
    catch ex
      @handleCompileError(ex)

  compileModules: ->
    @depend or= new Dependency(@modules)
    _stitch   = new Stitch(@paths)
    # TODO use detective....??
    _modules  = @depend.resolve().concat(_stitch.resolve())
    stitchFile(identifier: @identifier, modules: _modules)

  compileLibs: ->
    # TODO: check if lib is a folder, then pull in everything
    (fs.readFileSync(lib, 'utf8') for lib in @libs).join("\n")

class CssPackage extends Package

  constructor: (name, config = {}) ->
    super(name, config)

  compile: (minify = false) ->
    try 
      result = []
      for _path in @paths
        # TODO: currently this only works with index files, perhaps someday loop over the directory
        # contents and pickup the other files?? though with stylus can always get other content by mixins
        _path  = require.resolve(path.resolve(_path))
        delete require.cache[_path]
        result.push require(_path)
      # TODO: do we want a minify option for css or is that built into the compilers??
      result.join("\n")
    catch ex
      @handleCompileError(ex)

module.exports.createPackage = createPackage

  
