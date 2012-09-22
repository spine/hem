{resolve} = require('path')
fs        = require('fs')
compilers = require('./compilers')

class CSS
  constructor: (config = {}) ->
    try
      @path   = require.resolve(resolve(config.path))
      @target = config.target
    catch e
    
  compile: ->
    return unless @path
    delete require.cache[@path]
    require(@path)

  unlink: ->
    fs.unlinkSync(@target) if fs.existsSync(@target)
  
  createServer: ->
    (env, callback) =>
      callback(200,
        'Content-Type': 'text/css',
        @compile())
      
module.exports =
  CSS: CSS
  createPackage: (config) ->
    new CSS(config)
