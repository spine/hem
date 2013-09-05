fs           = require('fs')
file         = require('file')
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
    # TODO: would it not be better to just have a @get_type() function and do a switch on it?
    if @isJavascript()
      @compile = @compileJavascript
    else if @isCss()
      @compile = @compileCss
    else if @isCacheManifest()
      @compile = @compileCache
    else
      throw new Error "Package '#{@name}' does not have any compiler"

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
      result = uglify.minify(result, fromString: true).code if minify
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

  compileCache: ->
    # date header
    content = ['CACHE MANIFEST', '# ' + new Date(), 'CACHE:']
    # define the content
    root_path = @paths[0]

    # filter for all non hidden files and non-manifest files
    allowed_file = (filename) ->
      hidden_file = filename[0] is '.'
      cache_file =  mime.lookup(filename) is 'text/cache-manifest'
      not hidden_file and not cache_file

    file.walkSync root_path, (current, subdirs, filenames) ->
      return unless filenames?
      for filename in filenames when allowed_file(filename)
        full_path = current + '/' + filename
        result = full_path. # TODO: we could use a regex here instead of this
          # replace "./www/blah/blah" with blah/blah
          replace(root_path + '/', '').
          # replace "www/blah/blah" with blah/blah
          replace root_path.replace('./','') + '/', ''
        content.push result

    # all resources not listed in the above cache will be network accessible
    content.push 'NETWORK:', '*'
    content.join "\n"

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

  isCss: ->
    @contentType is "text/css"

  isCacheManifest: ->
    @contentType is "text/cache-manifest"

  unlink: ->
    fs.unlinkSync(@target) if fs.existsSync(@target)

  build: (minify = false, versionAddOn) ->
    console.log "Building '#{@name}' target: #{@target}"
    source = @compile(minify)
    fs.writeFileSync(@target, source) if source
    
  watch: ->
    console.log "Watching '#{@name}'"
    watchOptions = { persistent: true, interval: 1000, ignoreDotFiles: true }
    for dir in (path.dirname(lib) for lib in @libs).concat @paths
      continue unless fs.existsSync(dir)
      require('watch').watchTree dir, watchOptions, (file, curr, prev) =>
        @build() if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)

  middleware: (debug) =>
    (req, res, next) =>
      str = @compile(not debug)
      res.charset = 'utf-8'
      res.setHeader('Content-Type', @contentType)
      res.setHeader('Content-Length', Buffer.byteLength(str))
      res.end((req.method is 'HEAD' and null) or str)

module.exports = Package
