npath = require("path")
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
      if ex.stack
        console.error ex
      else
        console.trace ex
      result = "console.log(\"#{ex}\");"

  compileSingle: (path, parent) ->
    if path
      @stitch       = new Stitch([path])
      @modules = @stitch.resolveFiles(parent)
      if not @modules.length
        return null
    else
      @dependency or= new Dependency(@dependencies)
      @modules      = @dependency.resolve()
      mods = stitch(identifier: @identifier, modules: @modules)
      result = [@compileLibs(), mods, @extraJS].join("\n")

    return stitch(identifier: @identifier, modules: @modules)

  unlink: ->
    fs.unlinkSync(@target) if fs.existsSync(@target)

  createServer: ->
    (env, callback) =>
      callback(200,
        'Content-Type': 'text/javascript',
        @compile())

  createIServer: (prefix) ->
    (env, callback) =>
      console.log("hem server called with", env.pathInfo)
      if env.pathInfo.slice(-3) == '.js'
        path = env.pathInfo.slice(1, -3)
      else
        path = env.pathInfo.slice(1)
      if path == "#{prefix}/core"
        result = @compileSingle()
      else
        path = path
        result = @compileSingle(path, npath.resolve(prefix))

      if result
        callback(200,
          'Content-Type': 'text/javascript',
          result)
      else
        callback(400,
          'Content-Type': 'text/javascript',
          'No such file')

module.exports =
  compilers:  compilers
  Package:    Package
  createPackage: (config) ->
    new Package(config)
