fs           = require('fs')
eco          = require('eco')
uglify       = require('uglify-js')
compilers    = require('./compilers')
stitch       = require('../assets/stitch')
Dependencies = require('./dependencies')
Stitch       = require('./stitch')
{toArray}    = require('./utils')

class Package
  constructor: (config = {}) ->
    @identifier   = config.identifier ? 'require'
    @libs         = toArray(config.libs)
    @paths        = toArray(@paths)
    @dependencies = toArray(config.dependencies)

  compileModules: ->
    @dependency or= new Dependencies(@dependencies)
    @stitch       = new Stitch(@paths)
    @modules      = @dependency.resolve().concat(@stitch.resolve())
    stitch(identifier: @identifier, modules: @modules)
    
  compileLibs: ->
    (fs.readFileSync(path, 'utf8') for path in @libs).join("\n")
    
  compile: (compress = false) ->
    content = [@compileLibs(), @compileModules()].join("\n")
    content = uglify(content) if compress
    content
    
  createServer: ->
    (req, res, next) =>
      content = @compile()
      res.writeHead 200, 'Content-Type': 'text/javascript'
      res.end content

module.exports = 
  compilers:  compilers
  Package:    Package
  createPackage: (config) -> 
    new Package(config)