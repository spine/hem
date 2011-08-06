{extname, join, resolve} = require('path')
fs           = require('fs')
compilers    = require('./compilers')
{modulerize} = require('./resolve')
{flatten}    = require('./utils')

class Stitch
  constructor: (@paths = []) ->
    @paths = (resolve(path) for path in @paths)
  
  resolve: ->
    flatten(@walk(path) for path in @paths)

  # Private

  walk: (path, parent = path, result = []) ->
    for child in fs.readdirSync(path)
      child = join(path, child)
      stat  = fs.statSync(child)
      if stat.isDirectory()
        @walk(child, parent, result)
      else
        module = new Module(child, parent)
        result.push(module) if module.valid()
    result

class Module
  constructor: (@filename, @parent) ->
    @ext = extname(@filename).slice(1)
    @id  = modulerize(@filename.replace(@parent + '/', ''))
    
  compile: ->
    compilers[@ext](@filename)
    
  valid: ->
    !!compilers[@ext]
    
module.exports = Stitch