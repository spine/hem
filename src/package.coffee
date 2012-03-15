fs           = require('fs')
eco          = require('eco')
uglify       = require('uglify-js')
compilers    = require('./compilers')
stitch       = require('../assets/stitch')
Dependency   = require('./dependency')
Stitch       = require('./stitch')
{toArray}    = require('./utils')
if /^v0\.[012]/.test(process.version)
  sys        = require("sys")
else
  sys        = require("util")
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
  
  refresh: ->
    @compiled = null

  compile: (minify) ->
    result = [@compileLibs(), @compileModules()].join("\n")
    try
      result = uglify(result) if minify
    catch e
      fs.writeFileSync("error.js", result)
      sys.puts("#{e.message} at error.js:#{e.line}:#{e.col}")
      if e.stack
        sys.puts(e.stack)
    @cacheBust = crypto.createHash('md5').update(result).digest("hex")
    result

module.exports = 
  compilers:  compilers
  Package:    Package
  createPackage: (config) -> 
    new Package(config)