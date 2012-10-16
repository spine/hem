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

  createServer: ->
    (env, callback) =>
      callback(200,
        'Content-Type': 'text/javascript',
        @compile())

module.exports =
  compilers:  compilers
  Package:    Package
  createPackage: (config) ->
    new Package(config)
