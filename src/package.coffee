fs           = require('fs')
path         = require('path')
uglify       = require('uglify-js')
stitchFile   = require('../assets/stitch')
Dependency   = require('./dependency')
Stitch       = require('./stitch')
{toArray}    = require('./utils')
mime         = require('connect').static.mime

class Package
  constructor: (name, config = {}, argv = {}) ->
    @name        = name
    @argv        = argv
    # set config values
    @identifier  = config.identifier
    @target      = config.target
    @libs        = toArray(config.libs || [])
    @paths       = toArray(config.paths || [])
    @modules     = toArray(config.modules || [])
    @jsAfter     = config.jsAfter or ""
    @url         = config.url or ""
    # TODO: sanity checkes on config values??
    # determine content type based on target file name
    @contentType = mime.lookup(@target)
    # set correct compiler based on mime type, set @compile = javascriptCompiler
    if @isJavascript()
      @compile = @compileJavascript
    else
      @compile = @compileCss

  compileModules: ->
    @depend or= new Dependency(@modules)
    _stitch   = new Stitch(@paths)
    _modules  = @depend.resolve().concat(_stitch.resolve())
    stitchFile(identifier: @identifier, modules: _modules)

  compileLibs: ->
    # TODO: be able to handle being given a folder and loading each file...can this compile coffeescript??
    (fs.readFileSync(lib, 'utf8') for lib in @libs).join("\n")

  compileJavascript: (minify = false) ->
    try
      result = [@compileLibs(), @compileModules(), @jsAfter].join("\n")
      result = uglify(result) if minify
      result
    catch ex
      @handleCompileError(ex)

  compileCss: (minify = false) ->
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

  compileCache: (packages, versionAddOn)->
    #start with a date header
    #define content...
    #fs.writeFileSync('app.cache', content) if content
  
  handleCompileError: (ex) ->
    console.error ex.message
    console.error ex.path if ex.path
    console.error ex.location if ex.location
    # only return when in server/watch mode, otherwise exit
    switch @argv.command
      when "server" then return "console.log(\"#{ex}\");"
      when "watch"  then return ""
      else process.exit(1)

  isJavascript: ->
    @contentType is "application/javascript"

  unlink: ->
    fs.unlinkSync(@target) if fs.existsSync(@target)

  build: (minify = false, versionAddOn) ->
    # TODO: add an option to add timestamp or other string to the target js and css files
    #if versionAddOn
      #@target += "-#{versionAddOn}"
    console.log "Building '#{@name}' target: #{@target}"
    source = @compile(minify)
    fs.writeFileSync(@target, source) if source
    
  watch: ->
    console.log "Watching '#{@name}'"
    for dir in (path.dirname(lib) for lib in @libs).concat @paths
      # TODO: handle symlink files/directories here??
      continue unless fs.existsSync(dir)
      require('watch').watchTree dir, { persistent: true, interval: 1000 },  (file, curr, prev) =>
        @build() if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)

  middleware: (debug) =>
    (req, res, next) =>
      str = @compile(not debug)
      res.charset = 'utf-8'
      res.setHeader('Content-Type', @contentType)
      res.setHeader('Content-Length', Buffer.byteLength(str))
      res.end((req.method is 'HEAD' and null) or str)

module.exports = Package
