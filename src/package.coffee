fs           = require('fs')
path         = require('path')
uglify       = require('uglify-js')
stitch       = require('../assets/stitch')
Dependency   = require('./dependency')
Stitch       = require('./stitch')
{toArray}    = require('./utils')
mime         = require('connect').static.mime

class Package
  constructor: (name, config = {}) ->
    @name         = name
    @require      = config.require
    @libs         = toArray(config.libs || [])
    @paths        = toArray(config.paths || [])
    @modules      = toArray(config.modules || [])
    @target       = config.target
    @jsAfter      = config.jsAfter or ""
    @url          = config.url or ""
    # determine content type based on target
    @contentType  = mime.lookup(@target)
    # check required config values

  compileModules: ->
    @dependency or= new Dependency(@modules)
    @stitch       = new Stitch(@paths)
    @stuff        = @dependency.resolve().concat(@stitch.resolve())
    stitch(identifier: @require, modules: @stuff)

  compileLibs: ->
    (fs.readFileSync(lib, 'utf8') for lib in @libs).join("\n")

  compile: (minify = false) ->
    try
      if @isJavascript()
        result = [@compileLibs(), @compileModules(), @jsAfter].join("\n")
        result = uglify(result) if minify
        result
      else
        result = []
        for _path in @paths
          # TODO: currently this only works with index files, perhaps someday loop over the directory
          # contents and pickup the other files?? though with stylus can always get other content by mixins
          _path  = require.resolve(path.resolve(_path))
          delete require.cache[_path]
          result.push require(_path)
        result.join("\n")
    catch ex
      console.trace ex
      # only return when in server mode, otherwise exit
      # TODO: pass in mode as argument instead of checking process.argv??
      command = process.argv[2]
      switch command
        when "server" then return "console.log(\"#{ex}\");"
        when "watch"  then return ""
        when "build"  then process.exit(1)

  isJavascript: ->
    @contentType is "application/javascript"

  unlink: ->
    fs.unlinkSync(@target) if fs.existsSync(@target)

  build: (minify = false) ->
    console.log "Building #{@name} to target: #{@target}"
    source = @compile(minify)
    fs.writeFileSync(@target, source) if source

  watch: ->
    for dir in (path.dirname(lib) for lib in @libs).concat @paths
      continue unless fs.existsSync(dir)
      require('watch').watchTree dir, { persistent: true, interval: 1000 },  (file, curr, prev) =>
        @build() if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)

  # TODO: move this to a separate middleware class, pass in package to call compile and content type on..
  middleware: (req, res, next) =>
    str = @compile()
    res.charset = 'utf-8'
    res.setHeader('Content-Type', @contentType)
    res.setHeader('Content-Length', Buffer.byteLength(str))
    res.end((req.method is 'HEAD' and null) or str)

module.exports = Package
