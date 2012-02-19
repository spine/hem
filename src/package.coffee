fs           = require('fs')
eco          = require('eco')
uglify       = require('uglify-js')
compilers    = require('./compilers')
stitch       = require('../assets/stitch')
Dependency   = require('./dependency')
Stitch       = require('./stitch')
{toArray}    = require('./utils')
sys          = require('sys')
crypto       = require('crypto')

class Package
  constructor: (config = {}) ->
    @identifier   = config.identifier
    @libs         = toArray(config.libs)
    @paths        = toArray(config.paths)
    @dependencies = toArray(config.dependencies)
    @cacheBust    = ''

  compileModules: ->
    @dependency or= new Dependency(@dependencies)
    @stitch       = new Stitch(@paths)
    @modules      = @dependency.resolve().concat(@stitch.resolve())
    stitch(identifier: @identifier, modules: @modules)
    
  compileLibs: ->
    (fs.readFileSync(path, 'utf8') for path in @libs).join("\n")
    
  compile: (minify) ->
    result = [@compileLibs(), @compileModules()].join("\n")
    result = uglify(result) if minify
    @cacheBust = crypto.createHash('md5').update(result).digest("hex")
    result
    
  createServer: (app, path) =>
    return (env, callback) =>
      try
        if (env.requestMethod isnt 'GET') or (env.scriptName.substr(0, path.length - 1) is path)
          app(env, callback)
          return
        content = @compile()
        
        callback(200, 
          'Content-Type': 'text/javascript', 
          content)
      catch e
        sys.puts(e.message)
        if e.stack
          sys.puts(e.stack)
        callback(500, {}, e.message)

module.exports = 
  compilers:  compilers
  Package:    Package
  createPackage: (config) -> 
    new Package(config)