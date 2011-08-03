fs        = require('fs')
eco       = require('eco')
compilers = require('./compilers')
stitch    = require('../assets/stitch')
Sources   = require('./sources')

class Package
  constructor: (config = {}) ->
    @identifier  = config.identifier ? 'require'
    @libs        = config.libs    ? []
    @require     = config.require ? []
    @require     = [@require] if typeof @require is 'string'

  compileSources: ->
    @sources or= new Sources(@require)
    stitch(identifier: @identifier, sources: @sources.resolve())
    
  compileLibs: ->
    (fs.readFileSync(path, 'utf8') for path in @libs).join("\n")
    
  compile: ->
    [@compileLibs(), @compileSources()].join("\n")
    
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