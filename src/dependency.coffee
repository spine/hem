# builtins
_module   = require('module')
natives   = process.binding('natives')
path      = require('path')
fs        = require('fs')
# 3rd party
detective = require('detective')

# inspect the source for dependencies

from_source = (source, parent, opt, cb) ->
  cache          = opt.cache;
  ignore_missing = true
  requires       = detective(source)
  result         = []

  # remove duplicate requires with the same name
  # this avoids trying to process the require twice
  requires = requires.filter( (elem, idx) -> requires.indexOf(elem) is idx )

  (next = ->
    req = requires.shift()
    return cb(null, result) unless req

    # short require name
    id = req

    resolve req, parent, (err, full_path, ignore) ->
      return cb(err) if err

      if not full_path
        # if resolver ignored the native module we just push it manually
        if natives[id]
          result.push
            id   : id
            core : true
          return next()

        # skip the dependency if we can't find it
        return next() if (ignore_missing)

        # return error if missing
        return cb(new Error('Cannot find module: \'' + req + '\' ' + 'required from ' + parent.filename))

      # ignore indicates we should not process dependencies for this file
      # this is useful if we don't care about certain files being handled further
      # we still want the dependency added to the deps of the file we processed
      # but do not process this file or it's deps
      if ignore
        result.push
          id: id,
          filename: full_path
        return next()

      # new parent entry
      new_parent =
        id       : id
        filename : full_path
        paths    : parent.paths.concat(node_module_paths(full_path))

      # read file
      from_filename full_path, new_parent, opt, (err, deps, src) ->
        return cb(err) if err

        # build up response
        res =
          id: id,
          filename: full_path,
          deps: deps
        res.source = src if (opt.includeSource)
        result.push res

        # continue on
        next()

  )() 

from_filename = (filename, parent, opt, cb) ->
  cache = opt.cache

  # wtf is this cache?
  # appears to be the list of dependencies for this filename
  # what it really should be is the info
  cached = cache[filename]
  return cb(null, cached.deps, cached.src) if cached

  fs.readFile filename, 'utf8', (err, content) ->
    return cb(err) if err

    # must be set before the compile call to handle circular references
    result = cache[filename] = deps: []

    try
      from_source content, parent, opt, (err, deps) ->
        return cb(err) if err
        result.deps = deps
        # only cache source if caller will want the source
        result.src = content if opt.includeSource
        return cb(err, deps, content)
    catch err
      err.message = filename + ': ' + err.message
      throw err

# default resolver if none specified just resolves as node would

resolve = (id, parent, cb) ->
  cb(null, lookup_path(id, parent))

# lookup the full path to our module with local name 'name'

lookup_path = (name, parent) ->
  resolved_module = _module.Module._resolveLookupPaths(name, parent)
  paths = resolved_module[1]
  _module.Module._findPath(name, paths)

# return an array of node_module paths given a filename

node_module_paths = (filename) ->
  return _module.Module._nodeModulePaths(path.dirname(filename))

# process filename and callback with tree of dependencies
# the tree does have circular references when a child requires a parent

module.exports = (mod, opt, cb) ->
  opt or= {};
  if typeof opt is 'function'
    cb  = opt
    opt = {}

  # add the cache storage
  opt.cache or= {}

  # entry parent specifies the base node modules path
  entry_parent =
    id       : mod.id
    filename : mod.filename
    paths    : node_module_paths(mod.filename)

  # start process
  from_source(mod.source, entry_parent, opt, cb)
