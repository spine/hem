_path     = require('path')
fs        = require('fs')
compilers = require('./compilers')
Utils     = require('./utils')
Log       = require('./log')
glob      = require('globule')
# help with dependency resolution
detective = require('detective')
_module   = require('module')
natives   = process.binding('natives')

## --- Private

cache =
  file: {}
  byId: {}

# TODO: could cache.byId ever be a duplicate?? maybe use cache[ext].byId?? OR walk
#       can be refactored to be a map and that can be unique per stitch instance

baseFromGlob = (path) ->
  path   = _path.resolve(path)
  paths  = path.split('/')
  result = []
  for part in paths
    if '*' in part
      break
    else
      result.push part
  hmm = "#{result.join('/')}"

walk = (type, path, parent) ->
  result = []
  files  = glob.find(path)
  for file in files
    stat = fs.statSync(file)
    if stat.isFile()
      patch = createPatchFromPath
        type     : type
        fullPath : file
        parent   : parent
      result.push patch if patch
  result

# determine parameters to pass into Patch constructor

createPatchFromPath = (options) ->
  type     = options.type
  fullPath = options.fullPath
  parent   = options.parent
  # create if it doesn't exist yet
  if not cache.file[fullPath]
    id    = modulerize(fullPath, parent, _path.extname(fullPath))
    patch = new Patch(id, fullPath, type)
    # TODO: memory leak if patch isn't valid??
  # return result (if any)
  cache.file[fullPath]

# determine the id value to use

modulerize = (filename, parent, ext) ->
  # deal with relative modules from npm
  if filename[0] is "."
    parts    = parent.split(_path.sep)
    parent   = parent.replace(/(node_modules(\/|\\)[^/\\]+)\/.+/,"$1")
    filename = _path.resolve(parent, filename)
    id       = filename.replace(/.+node_modules(\/|\\)/,"")
  # coming from src folders
  else
    id = filename.replace(_path.join(parent, _path.sep), '')
  # set variables
  baseName = if ext then _path.basename(id, ext) else _path.basename(id)
  dirName  = _path.dirname(id)
  modName  = _path.join(_path.dirname(id), baseName)
  # deal with window _path separator
  modName.replace(/\\/g, '/')

findAllDependencies = (patch, patches, options) ->
  deps = patch.deps or= depsFromPatch(patch, options)
  (next = ->
    id = deps.shift()
    return unless id
    # place depends in array if we haven't seen it before
    dep = cache.byId[id]
    if dep not in patches
      patches.push dep
      findAllDependencies(dep, patches, options)
    next()
  )()

## --- classes

class Stitch

  ## --- class methods

  # keep track of all stitch instances
  @instances: []

  # TODO: have per instance settings via options? setup global values that can be tweaked.
  @ignoreMissingDependencies: true
  @reportMissingDependencies: false

  # Different bundling options for js and css
  @resolvers:
    js: (patches, options = {}) ->
      # set dependency options
      options.ignoreMissingDependencies or= Stitch.ignoreMissingDependencies
      options.reportMissingDependencies or= Stitch.reportMissingDependencies

      if options.reportMissingDependencies or !options.ignoreMissingDependencies or options.npm
        # resolve npm modules and other dependencies
        findAllDependencies(patch, patches, options) for patch in patches

      # bundling options
      if options.bundle
        if options.commonjs
          identifier = if typeof options.commonjs is 'boolean' then 'require' else options.commonjs
          source: Stitch.bundle(patches, identifier)
        else
          source: Stitch.join(patches, options.separator)
      else
        patches

    css: (patches, options = {}) ->
      if options.bundle
        source: Stitch.join(patches, options.separator)
      else
        patches

  @bundle: (patches, identifier) ->
    context =
      identifier : identifier
      modules    : patches
    Utils.tmpl("stitch", context)

  @join: (patches, separator = "\n") ->
    (patch.source for patch in patches).join(separator)

  @remove: (filename) ->
    patch = cache.file[_path.resolve(filename)]
    return unless patch

    # delete global cache
    delete cache.file[patch.filename]
    delete cache.byId[patch.id]

    # remove cache from stitch instances
    for stitch in @instances
      for patch in stitch.walk when stitch.cache
        # TODO: use the globule.isMatching instead!!
        delete stitch.cache if patch.filename is filename


  @register: (stitch) ->
    @instances.push stitch

  ## --- instance methods

  constructor: (@paths = [], @type = 'js' ) ->
    @paths = (_path.resolve(path) for path in @paths)
    unless Stitch.resolvers[@type]
      throw new Error("Invalid type supplied to Stitch contructor")
    Stitch.register(@)

  resolve: (options = {}) ->
    unless @cache
      @walk = []
      for path in @paths
        parent = baseFromGlob(path)
        @walk.push.apply @walk, walk(@type, path, parent)
      @cache = Stitch.resolvers[@type](@walk, options)
    @cache

class Patch

  constructor: (@id, @filename, @type = "js") ->
    ext = _path.extname(@filename).slice(1).toLowerCase()

    # add to cache if valid
    if compilers[ext]
      # setup compile function
      @source or= compilers[ext](@filename)
      # place in cache
      cache.file[@filename] = @
      cache.byId[@id] = @ if @id

## --- dependency helpers

# lookup the full path to our module with local name 'name'
# review https://github.com/joyent/node/blob/master/lib/module.js#L224

lookup_path = (name, parent) ->
  resolved_module = _module.Module._resolveLookupPaths(name, parent)
  paths = resolved_module[1]
  _module.Module._findPath(name, paths)

# return an array of node_module paths given a filename

node_module_paths = (filename) ->
  return _module.Module._nodeModulePaths(_path.dirname(filename))

resolve = (id, parent, cb) ->
  parent.paths or= node_module_paths(parent.filename)
  cb(lookup_path(id, parent))

depsFromPatch = (patch, options) ->
  result   = [] # string of ids
  # remove duplicate requires with the same name
  requires = detective(patch.source)
  requires = requires.filter( (elem, idx) -> requires.indexOf(elem) is idx )

  (next = ->
    req = requires.shift()
    return result unless req

    # create id that will be used by browser
    id = modulerize(req, patch.filename)

    resolve req, patch, (full_path) ->
      # handle case of full_path being undefined
      if not full_path
        # check current list of modules in stitch cache
        if cache.byId[id]
          result.push id
          return next()
        # for now don't allow native modules to be loaded
        if natives[id] and options.npm
          throw new Error('Cannot require native module: \'' + req + '\' from ' + patch.filename)
        # handle missing dependency
        if options.ignoreMissingDependencies is false
          throw new Error "#{patch.filename} contains missing module #{id}"
        if options.reportMissingDependencies
          Log.info "<yellow>Warning:</yellow> #{patch.filename} contains missing module <green>#{id}</green>"
        return next()
      
      return next() unless options.npm
      # see if we have already processed this path
      dep = cache.file[full_path]
      if dep
        result.push dep.id
        return next()

      # new patch/module entry
      newPatch = new Patch(id, full_path)
      if newPatch
        newPatch.paths  = patch.paths.concat(node_module_paths(full_path))
        newPatch.npm    = true
        newPatch.alias  = req
        result.push newPatch.id
        # process deps for this module
        newPatch.deps or= depsFromPatch(newPatch, options)
        # continue on
        next()
  )()

module.exports = Stitch
