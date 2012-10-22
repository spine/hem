fs           = require('fs')
eco          = require('eco')
uglify       = require('uglify-js')
compilers    = require('./compilers')
stitch       = require('../assets/stitch')
Dependency   = require('./dependency')
Stitch       = require('./stitch')
{toArray}    = require('./utils')

class Package
  constructor: (config = {}) ->
    @identifier   = config.identifier
    @libs         = toArray(config.libs || [])
    @paths        = toArray(config.paths || [])
    @dependencies = toArray(config.dependencies || [])
    @target       = config.target
    @extraJS      = config.extraJS or ""
    @test         = config.test

  compileModules: ->
    @dependency or= new Dependency(@dependencies)
    @stitch       = new Stitch(@paths)
    @modules      = @dependency.resolve().concat(@stitch.resolve())
    stitch(identifier: @identifier, modules: @modules)

  compileLibs: ->
    (fs.readFileSync(path, 'utf8') for path in @libs).join("\n")

  compile: (minify) ->
    try
      result = [@compileLibs(), @compileModules(), @extraJS].join("\n")
      result = uglify(result) if minify
      result
    catch ex
      console.log ex.message
      result = "console.log(\"#{ex.message}\");"

  unlink: ->
    fs.unlinkSync(@target) if fs.existsSync(@target)

  # TODO: move this to a separate middleware class, pass in package to call compile and content type on..
  middleware: (req, res, next) =>
    str = @compile()
    contentType = "text/javascript"
    res.charset = 'utf-8'
    res.setHeader('Content-Type', contentType)
    res.setHeader('Content-Length', Buffer.byteLength(str))
    res.end((req.method is 'HEAD' and null) or str)

module.exports =
  compilers:  compilers
  Package:    Package
  createPackage: (config) ->
    new Package(config)
