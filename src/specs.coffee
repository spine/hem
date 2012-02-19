stitch = require('../assets/stitch')
Stitch = require('./stitch')
sys = require('sys')

class Specs
  constructor: (@path) -> 
  
  compile: ->
    @stitch  = new Stitch([@path])
    stitch(identifier: 'specs', modules: @stitch.resolve())

  createServer: (app, path) =>
    (env, callback) =>
      try
        if (env.requestMethod isnt 'GET') or (env.scriptName.substr(0, path.length - 1) is path)
          app(env, callback)
          return
        content = @compile()
        callback(200, 
          'Content-Type': 'text/javascript', 
          content)
      catch e
        sys.puts(e.message)
        if e.stack
          sys.puts(e.stack)
        callback(500, {}, e.message)
      
module.exports = 
  Specs: Specs
  createPackage: (path) ->
    new Specs(path)