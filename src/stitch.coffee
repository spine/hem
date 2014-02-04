_path        = require('path')
fs           = require('fs')
compilers    = require('./compilers')
Utils        = require('./utils')

## --- Private

# TODO: replace with node-glob file list
walk = (type, modules, path, parent = path, result = []) ->
  return unless fs.existsSync(path)
  for child in fs.readdirSync(path)
    child = _path.join(path, child)
    stat  = fs.statSync(child)
    if stat.isDirectory()
      walk(type, modules, child, parent, result)
    else
      module = createModule(type, modules, child, parent)
      result.push module
  result

createModule = (type, modules, child, parent) ->
  if not modules[child]
    module = new Module(child, parent, type)
    if module.valid() and module.compile()
      modules[child] = module
  modules[child]

# Normalize paths and remove extensions
# to create valid CommonJS module names
modulerize = (id, filename = id) ->
  ext      = _path.extname(filename)
  dirName  = _path.dirname(id)
  baseName = _path.basename(id, ext)
  # Do not allow names like 'underscore/underscore'
  if dirName is baseName
    modName = baseName
  else
    modName = _path.join(_path.dirname(id), _path.basename(id, ext))
  # deal with window path separator
  modName.replace(/\\/g, '/')


## --- classes

class Stitch

  ## --- class methods

  @bundle: (identifier, modules) ->
    context =
      identifier : identifier
      modules    : modules
    Utils.tmpl("stitch", context )

  ## --- instance methods

  constructor: (@paths = [], @type = 'js' ) ->
    @paths   = (_path.resolve(path) for path in @paths)
    @modules = {}

  bundle: (indentifier) ->
    Stitch.bundle(identifier, @resolve)

  join: (separator = "\n") ->
    (module.compile() for module in @resolve()).join(separator)

  resolve: ->
    # return array of modules 
    Utils.flatten(walk(@type, @modules, path) for path in @paths)

  clear: (filename) ->
    delete modules[_path.resolve(filename)]

# TODO: probably not the best name, what else could be used?? unit, item, node...
class Module
  constructor: (@filename, @parent, @type) ->
    @ext = _path.extname(@filename).slice(1)
    @id  = modulerize(@filename.replace(_path.join(@parent, _path.sep), ''))

  compile: ->
    @out or= compilers[@ext](@filename)

  valid: ->
    !!compilers[@ext]

module.exports = Stitch
