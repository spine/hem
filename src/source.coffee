{extname} = require('path')
{wrap}    = require('module')
detective = require('detective')
resolve   = require('./resolve')
compilers = require('./compilers')

class Source
  @walk: ['js', 'coffee']
  
  @resolve: (path, name = '.', results = {}) ->
    [name, path] = resolve(name, path)
    
    # Return if we've already seen this file
    return if results[path]
    results[path] = source = new @(name, path)
    
    # Add other referenced scripts to the results object
    @resolve(dep, name, results) for dep in source.paths()
    return (value for key, value of results)
    
  constructor: (name, path) ->
    @name = name
    @path = path
    @ext  = extname(@path).slice(1)    

  compile: ->
    @_compile or= compilers[@ext](@path)
    
  module: ->
    wrap(@compile())
  
  paths: ->
    if @ext in @constructor.walk
      # Find `require()` calls
      detective(@compile())
    else 
      []
      
module.exports = Source