npath        = require('path')
fs           = require('fs')
compilers    = require('./compilers')
{modulerize} = require('./resolve')
{flatten}    = require('./utils')
_ = require('underscore')

class Stitch
  ignores : [/.*~/, /^#/, /^\.#/]
  constructor: (@paths = []) ->
    @paths = (npath.resolve(path) for path in @paths)

  resolve: ->
    flatten(@walk(path) for path in @paths)

  resolveFiles: (parent) ->
    result= []
    for path in @paths
      console.log("path", path + '.coffee');
      if fs.existsSync(path + '.coffee')
        child =  path + '.coffee'
        console.log("exists", child);
        console.log('building single module', child, parent)
        module = new Module(child, parent)
        result.push(module) if module.valid()
    result

  # Private

  walk: (path, parent = path, result = []) ->
    return unless fs.existsSync(path)
    for child in fs.readdirSync(path)
      if _.any(_.map(@ignores, (ignore) -> return child.match(ignore)))
        continue
      child = npath.join(path, child)
      stat  = fs.statSync(child)
      if stat.isDirectory()
        @walk(child, parent, result)
      else
        #hack
        console.log('building module', child, parent)
        module = new Module(child, parent)
        result.push(module) if module.valid()
    result

class Module
  constructor: (@filename, @parent) ->
    @ext = npath.extname(@filename).slice(1)
    @id  = modulerize(@filename.replace(npath.join(@parent, npath.sep), ''))

  compile: ->
    compilers[@ext](@filename)

  valid: ->
    !!compilers[@ext]

module.exports = Stitch
