fs        = require('fs')
eco       = require('eco')
compilers = require('./compilers')
stitch    = require('../assets/stitch')
Source    = require('./source')

class Package
  constructor: (config = {}) ->
    @identifier  = config.identifier ? 'require'
    @libs        = config.libs    ? []
    @require     = config.require ? []
    @require     = [@require] if typeof @require is 'string'
  
  compileSources: ->
    sources = []
    sources = sources.concat Source.resolve(path) for path in @require
    stitch(identifier: @identifier, sources: sources)
    
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
  Source:     Source
  Package:    Package
  createPackage: (config) -> 
    new Package(config)