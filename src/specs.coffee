stitch = require('../assets/stitch')
Stitch = require('./stitch')

class Specs
  constructor: (@path) -> 
  
  compile: ->
    @stitch  = new Stitch([@path])
    stitch(identifier: 'specs', modules: @stitch.resolve())

  createServer: (app, path) =>
    (env, callback) =>
      if (env.requestMethod isnt 'GET') or (env.scriptName istn path)
        app(env, callback)
        return
      callback(200, 
        'Content-Type': 'text/javascript', 
        @compile())
      
module.exports = 
  Specs: Specs
  createPackage: (path) ->
    new Specs(path)