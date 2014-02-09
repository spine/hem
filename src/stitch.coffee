_path        = require('path')
fs           = require('fs')
compilers    = require('./compilers')
Utils        = require('./utils')

# TODO: provide global settings for stitch
# ignoreMissingDependencies = true

## --- Private

_patchesByFile = {}
_patchesById   = {}

# TODO: replace with node-glob file list
walk = (type, path, parent = path, result = []) ->
  return unless fs.existsSync(path)
  for child in fs.readdirSync(path)
    child = _path.join(path, child)
    stat  = fs.statSync(child)
    if stat.isDirectory()
      walk(type, child, parent, result)
    else
      patch = createPatch(type, child, parent)
      result.push patch
  result

createPatch = (type, child, parent) ->
  if not _patchesByFile[child]
    patch = new Patch(child, parent, type)
    if patch.valid() and patch.compile()
      _patchesByFile[child]  = patch
      _patchesById[patch.id] = patch if patch.id
  _patchesByFile[child]

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
  js: (patches, options = {}) ->
    # resolve npm modules
    if options.npm
      for patch in patches
        patch.depends()

    # bundling options
    if options.bundle
      if options.commonjs
        identifier = if typeof options.commonjs is 'boolean' then 'require' else options.commonjs
        Stitch.bundle(patches, identifier)
      else
        Stitch.join(patches, options.separator)
    else
      patches

  css: (patches, options = {}) ->
    if options.bundle
      Stitch.join(patches, options.separator)
    else
      patches

## --- classes

class Stitch

  ## --- class methods

  @bundle: (patches, identifier) ->
    context =
      identifier : identifier
      modules    : patches
    Utils.tmpl("stitch", context )

  @join: (patches, separator = "\n") ->
    (patch.compile() for patch in patches).join(separator)

  @delete: (filename) ->
    patch = _patchesByFile(_path.resolve(filename))
    if patch
      delete _patchesByFile[patch.filename]
      delete _patchesById[patch.id]

  ## --- instance methods

  constructor: (@paths = [], @type = 'js' ) ->
    @paths = (_path.resolve(path) for path in @paths)
    unless resolvers[@type]
      throw new Error("Invalid type supplied to Stitch contructor")

  resolve: (options = {}) ->
    patches = Utils.flatten(walk(@type, path) for path in @paths)
    resolvers[@type](patches, options)

class Patch

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
