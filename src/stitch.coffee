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

## --- classes

class Stitch

  ## --- class methods

  # keep track of all stitch instances
  @instances: []

  # TODO: have per instance settings via options? setup global values that can be tweaked.
  @ignoreMissingDependencies: true
  @reportMissingDependencies: false

  # Different bundling options for js and css
  # probably can merge these, though still need ext type for non bundles
  @resolvers:
    js: (sources, options = {}) ->
      # set dependency options
      options.ignoreMissingDependencies or= Stitch.ignoreMissingDependencies
      options.reportMissingDependencies or= Stitch.reportMissingDependencies

      if options.reportMissingDependencies or !options.ignoreMissingDependencies or options.npm
        # resolve npm modules and other dependencies
        findAllDependencies(source, sources, options) for source in sources

      # bundling options
      if options.bundle
        if options.commonjs
          identifier = if typeof options.commonjs is 'boolean' then 'require' else options.commonjs
          source: Stitch.bundle(sources, identifier)
        else
          source: Stitch.join(sources, options.separator)
      else
        sources

    css: (sources, options = {}) ->
      # if target undefined simply return results
      sources unless options.target
      # if target is a single file then join
      if _path.extname(filename)
        source = Stitch.join(sources, options.separator)
      else
        

  @bundle: (sources, identifier) ->
    context =
      identifier : identifier
      modules    : sources
    Utils.tmpl("stitch", context)

  @join: (sources, separator = "\n") ->
    (source.source for source in sources).join(separator)

  @remove: (filename) ->
    source = cache.file[_path.resolve(filename)]
    return unless source

    # delete global cache
    delete cache.file[source.filename]
    delete cache.byId[source.id]

    # remove cache from stitch instances
    for stitch in @instances
      for source in stitch.walk when stitch.cache
        # TODO: use the globule.isMatching instead!!
        delete stitch.cache if source.filename is filename

  @registerInstance: (stitch) ->
    @instances.push stitch

  ## --- instance methods

  constructor: (@paths = [], @type = 'js' ) ->
    unless Stitch.resolvers[@type]
      throw new Error("Invalid type value supplied to Stitch contructor")
    Stitch.registerInstance(@)

  resolve: (options = {}) ->
    unless @cache
      walk = []
      for path in @paths

        # get files from path object
        for file in path.walk()
          continue if fs.statSync(file).isDirectory()
          source = Source.createFromPath(file, path, @type)
          walk.push source if source

      # create final results
      console.log walk
      @cache = Stitch.resolvers[@type](walk, options)
      console.log @cache
    @cache

class Source

  @modulerize = (filename, parent) ->
    ext = _path.extname(filename)
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

  @isValid: (filename) ->
    ext = _path.extname(filename).slice(1).toLowerCase()
    !!compilers[ext]

  @createFromPath = (filename, path, type) ->
    # create if it doesn't exist yet
    if not cache.file[filename] and Source.isValid(filename)
      src = new Source(filename, path, type)
    # return result (if any)
    cache.file[filename]

  constructor: (@filename, @path, @type = "js") ->
    @ext = _path.extname(@filename).slice(1).toLowerCase()
    @id  = Source.modulerize(filename, @path.srcBase) if @type is "js"

    # setup compile function
    @source = compilers[@ext](@filename)

    # store in cache
    cache.file[@filename] = @
    cache.byId[@id] = @ if @id

## --- dependency helpers

findAllDependencies = (source, sources, options) ->
  deps = source.deps or= depsFromSource(source, options)
  (next = ->
    id = deps.shift()
    return unless id
    # place depends in array if we haven't seen it before
    dep = cache.byId[id]
    if dep not in sources
      sources.push dep
      findAllDependencies(dep, sources, options)
    next()
  )()

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

depsFromSource = (source, options) ->
  result   = [] # string of ids
  # remove duplicate requires with the same name
  requires = detective(source.source)
  requires = requires.filter( (elem, idx) -> requires.indexOf(elem) is idx )

  (next = ->
    req = requires.shift()
    return result unless req

    # create id that will be used by browser
    id = modulerize(req, source.filename)

    resolve req, source, (full_path) ->
      # handle case of full_path being undefined
      if not full_path
        # check current list of modules in stitch cache
        if cache.byId[id]
          result.push id
          return next()
        # for now don't allow native modules to be loaded
        if natives[id] and options.npm
          throw new Error('Cannot require native module: \'' + req + '\' from ' + source.filename)
        # handle missing dependency
        if options.ignoreMissingDependencies is false
          throw new Error "#{source.filename} contains missing module #{id}"
        if options.reportMissingDependencies
          Log.info "<yellow>Warning:</yellow> #{source.filename} contains missing module <green>#{id}</green>"
        return next()

      return next() unless options.npm
      # see if we have already processed this path
      dep = cache.file[full_path]
      if dep
        result.push dep.id
        return next()

      # new source/module entry
      newSource = new Source(id, full_path)
      if newSource
        newSource.paths  = source.paths.concat(node_module_paths(full_path))
        newSource.npm    = true
        newSource.alias  = req
        result.push newSource.id
        # process deps for this module
        newSource.deps or= depsFromSource(newSource, options)
        # continue on
        next()
  )()

module.exports = Stitch
