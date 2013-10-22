npath        = require('path')
fs           = require('fs')
compilers    = require('./compilers')
{modulerize} = require('./resolve')
{flatten}    = require('./utils')


## --- Private

_modules = {}

_walk = (path, parent = path, result = []) ->
  return unless fs.existsSync(path)
  for child in fs.readdirSync(path)
    child = npath.join(path, child)
    stat  = fs.statSync(child)
    if stat.isDirectory()
      _walk(child, parent, result)
    else
      module = _createModule(child, parent)
      result.push(module) if module.valid()
  result

_createModule = (child, parent) ->
  if not _modules[child]
    _modules[child] = new Module(child, parent)
  _modules[child]

## --- classes

class Stitch

  ## --- class methods

  @template: (identifier, modules) ->
    context =
      identifier : identifier
      modules    : modules
    require('./utils').tmpl("stitch", context )

  @clear: (filename) ->
    delete _modules[npath.resolve(filename)]

  ## --- instance methods

  constructor: (@paths = []) ->
    @paths = (npath.resolve(path) for path in @paths)

  resolve: ->
    flatten(_walk(path) for path in @paths)

class Module
  constructor: (@filename, @parent) ->
    @ext = npath.extname(@filename).slice(1)
    @id  = modulerize(@filename.replace(npath.join(@parent, npath.sep), ''))

  compile: ->
    @_compiled or= compilers[@ext](@filename)

  valid: ->
    !!compilers[@ext]

    
module.exports = Stitch
