{resolve} = require('path')
compilers = require('./compilers')

class CSS
  constructor: (@path) ->
    
  compile: ->
    require(resolve(@path))
  
  createServer: ->
    (req, res, next) =>
      content = @compile()
      res.writeHead 200, 'Content-Type': 'text/css'
      res.end content
      
module.exports = 
  CSS: CSS
  createPackage: (path) ->
    new CSS(path)