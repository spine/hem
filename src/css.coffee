{resolve} = require('path')
compilers = require('./compilers')

class CSS
  constructor: (path) ->
    try
      @path = require.resolve(resolve(path))
    catch e
    
  compile: ->
    return unless @path
    delete require.cache[@path]
    require(@path)
  
  createServer: (app, path) =>
    return (env, callback) =>
      if (env.requestMethod isnt 'GET') or (env.scriptName isnt path)
        app(env, callback)
        return
      callback(200, 
        'Content-Type': 'text/css', 
        @compile())
      
module.exports = 
  CSS: CSS
  createPackage: (path) ->
    new CSS(path)