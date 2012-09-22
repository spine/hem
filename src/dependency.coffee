{extname} = require('path')
fs        = require('fs')
detective = require('fast-detective')
resolve   = require('./resolve')
compilers = require('./compilers')

mtime = (path) ->
  fs.statSync(path).mtime.valueOf()

class Module
  @walk: ['js', 'coffee']
    
  constructor: (request, parent) ->
    [@id, @filename] = resolve(request, parent)
    @ext   = extname(@filename).slice(1)
    @mtime = mtime(@filename)
    @paths = resolve.paths(@filename)

  compile: ->
    if not @_compile or @changed()
      @mtime    = mtime(@filename)
      @_compile = compilers[@ext](@filename)
    @_compile
      
  modules: ->
    if not @_modules or @changed()
      @_modules = @resolve()
    @_modules
  
  changed: ->
    @mtime isnt mtime(@filename)
    
  resolve: ->
    for path in @calls()
      new @constructor(path, @)
  
  # Find calls to require()
  calls: ->
    if @ext in @constructor.walk
      detective(@compile())
    else []

class Dependency
  constructor: (paths = []) ->
    @paths = paths

  resolve: ->
    @modules or= (new Module(path) for path in @paths)
    @deepResolve(@modules)

  # Private

  deepResolve: (modules = [], result = [], search = {}) ->
    for module in modules when not search[module.filename]
      search[module.filename] = true
      result.push(module)
      @deepResolve(
        module.modules(),
        result
        search
      )
    result
    
module.exports = Dependency
module.exports.Module = Module
