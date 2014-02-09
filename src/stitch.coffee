_path        = require('path')
fs           = require('fs')
compilers    = require('./compilers')
Utils        = require('./utils')

# TODO: provide global settings for stitch
# ignoreMissingDependencies = true

## --- Private

_modulesByFile = {}
_modulesById   = {}

# TODO: replace with node-glob file list
walk = (type, path, parent = path, result = []) ->
  return unless fs.existsSync(path)
  for child in fs.readdirSync(path)
    child = _path.join(path, child)
    stat  = fs.statSync(child)
    if stat.isDirectory()
      walk(type, child, parent, result)
    else
      module = createModule(type, child, parent)
      result.push module
  result

createModule = (type, child, parent) ->
  if not _modulesByFile[child]
    module = new Module(child, parent, type)
    if module.valid() and module.compile()
      _modulesByFile[child]   = module
      _modulesById[module.id] = module if module.id
  _modulesByFile[child]

# Normalize paths and remove extensions
# to create valid CommonJS module names
modulerize = (filename, parent) ->
  id       = filename.replace(_path.join(parent, _path.sep), '')
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

# Different bunlding options for js and css
resolvers =
  js: (modules, options = {}) ->
    # resolve npm modules
    if options.npm
      for mod in modules
        mod.depends()

    # bundling options
    if options.bundle
      if options.commonjs
        identifier = if typeof options.commonjs is 'boolean' then 'require' else options.commonjs
        Stitch.bundle(modules, identifier)
      else
        Stitch.join(modules, options.separator)
    else
      modules

  css: (modules, options = {}) ->
    if options.bundle
      Stitch.join(modules, options.separator)
    else
      modules

## --- classes

class Stitch

  ## --- class methods

  @bundle: (modules, identifier) ->
    context =
      identifier : identifier
      modules    : modules
    Utils.tmpl("stitch", context )

  @join: (modules, separator = "\n") ->
    (mod.compile() for mod in modules).join(separator)

  @delete: (filename) ->
    mod = _modulesByFile(_path.resolve(filename))
    if mod
      delete modulesByFile[mod.filename]
      delete modulesById[mod.id]

  ## --- instance methods

  constructor: (@paths = [], @type = 'js' ) ->
    @paths = (_path.resolve(path) for path in @paths)
    unless resolvers[@type]
      throw new Error("Invalid type supplied to Stitch contructor")

  resolve: (options = {}) ->
    modules = Utils.flatten(walk(@type, path) for path in @paths)
    resolvers[@type](modules, options)

# TODO: probably not the best name, what else could be used?? unit, item, node...
class Module

  constructor: (@filename, @parent, @type) ->
    @ext = _path.extname(@filename).slice(1)
    if @type is "js"
      @id  = modulerize(@filename, @parent)

  compile: ->
    @source or= compilers[@ext](@filename)

  depends: ->
    require('./dependency')(@, (err, res) =>
      console.log @id, err, res if res.length > 200
    )
    # need to cache/save results
    # return array of Modules, need a new name!!
    # way to find missing deps without errors?
    # need to modify inner deps based on parent id?? or just path from node_modules directory!

  valid: ->
    !!compilers[@ext]

module.exports = Stitch
