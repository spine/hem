{extname} = require('path')
fs        = require('fs')
detective = require('fast-detective')
resolve   = require('./resolve')
compilers = require('./compilers')

mtime = (path) ->
  fs.statSync(path).mtime.valueOf()

class Sources
  constructor: (paths = []) ->
    @paths = paths
    
  resolve: ->
    @sources or= Source.resolvePaths(@paths)
    @resolveSources(@sources)

  # Private
  
  resolveSources: (sources = [], result = [], search = {}) ->
    for source in sources when not search[source.path]
      search[source.path] = true
      result.push(source)
      @resolveSources(
        source.sources(), 
        result
        search
      )
    result

class Source
  @walk: ['js', 'coffee']
  
  @resolvePaths: (paths) ->
    results = []
    for path in paths
      for source in @resolve(path, '.')
        results.push(source)
    results
  
  @resolve: (path, name = '.', results = []) ->
    [name, path] = resolve(name, path)
    
    source = new @(name, path)
    results.push(source)
    
    for dep in source.paths()
      @resolve(dep, name, results)
    results
    
  constructor: (name, path) ->
    @name = name
    @path = path
    @ext  = extname(@path).slice(1)    

  compile: ->
    return @_compile unless @changed()
    @mtime    = mtime(@path)
    @_compile = compilers[@ext](@path)
      
  sources: ->
    if not @_sources or @changed()
      @_sources = @constructor.resolvePaths(@paths())
    @_sources
  
  changed: ->
    !@mtime or @mtime isnt mtime(@path)
    
  # Private
  
  # Find `require()` calls
  paths: ->
    if @ext in @constructor.walk
      detective(@compile())
    else 
      []
      
module.exports = Sources