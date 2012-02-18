{resolve} = require('path')
compilers = require('./compilers')
crypto    = require('crypto')
sys       = require('sys')

class CSS
  constructor: (path) ->
    @cacheBust = ''
    try
      @path = require.resolve(resolve(path))
    catch e
  
  compile: ->
    return unless @path
    delete require.cache[@path]
    result = require(@path)
    @cacheBust = crypto.createHash('md5').update(result).digest("hex")
    result
  
  createServer: (app, path) =>
    return (env, callback) =>
      if (env.requestMethod isnt 'GET') or (env.scriptName.substr(0, path.length - 1) is path)
        app(env, callback)
        return
      try
        content = @compile()
        callback(200, 
          'Content-Type': 'text/css', 
          content)
      catch e
        sys.puts(e.message)
        if e.stack
          sys.puts(e.stack)
        callback(500, {}, e.message)
      
module.exports = 
  CSS: CSS
  createPackage: (path) ->
    new CSS(path)