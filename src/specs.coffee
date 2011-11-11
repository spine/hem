stitch = require('../assets/stitch')
Stitch = require('./stitch')

class Specs
  constructor: (@path) ->    
  
  compile: ->
    @stitch  = new Stitch([@path])
    stitch(identifier: @identifier, modules: @stitch.resolve())

  createServer: ->
    (req, res, next) =>
      content = @compile()
      res.writeHead 200, 'Content-Type': 'text/javascript'
      res.end content
      
module.exports = 
  Specs: Specs
  createPackage: (path) ->
    new Specs(path)