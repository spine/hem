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
    @sources or= (new Source('.', path) for path in @paths)
    @deepResolve(@sources)

  # Private
  
  deepResolve: (sources = [], result = [], search = {}) ->
    for source in sources when not search[source.path]
      search[source.path] = true
      result.push(source)
      @deepResolve(
        source.sources(), 
        result
        search
      )
    result

class Source
  @walk: ['js', 'coffee']
    
  constructor: (name, path) ->
    # Calculate real name/path
    [name, path] = resolve(name, path)
    
    @name  = name
    @path  = path
    @ext   = extname(@path).slice(1)    
    @mtime = mtime(@path)

  compile: ->
    if not @_compile or @changed()
      @mtime    = mtime(@path)
      @_compile = compilers[@ext](@path)
    @_compile
      
  sources: ->
    if not @_sources or @changed()
      @_sources = @resolve()
    @_sources
  
  changed: ->
    @mtime isnt mtime(@path)
    
  resolve: ->
    for path in @paths()
      new @constructor(@name, path)
  
  # Find calls to require()
  paths: ->
    if @ext in @constructor.walk
      detective(@compile()) 
    else []
      
module.exports = Sources