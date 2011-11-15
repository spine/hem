{resolve} = require('path')
compilers = require('./compilers')

class CSS
  constructor: (path) ->
    @path = resolve(path)
    @path = require.resolve(@path)
    
  compile: ->
    delete require.cache[@path]
    require(@path)
  
  createServer: ->
    (req, res, next) =>
      callback(200, 
        'Content-Type': 'text/css', 
        @compile())
      
module.exports = 
  CSS: CSS
  createPackage: (path) ->
    new CSS(path)