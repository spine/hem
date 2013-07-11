Module = require('module')
{join, extname, dirname, basename, resolve, sep} = require('path')

isAbsolute = (path) -> /^\//.test(path)

# Normalize paths and remove extensions
# to create valid CommonJS module names
modulerize = (id, filename = id) ->
  ext = extname(filename)
  dirName = dirname(id)
  baseName = basename(id, ext)
  # Do not allow names like 'underscore/underscore'
  if dirName is baseName
    modName = baseName
  else
    modName = join(dirname(id), basename(id, ext))
  # deal with window path separator
  modName.replace(/\\/g, '/')

modulePaths = Module._nodeModulePaths(process.cwd())
invalidDirs = ['/', '.']

repl =
  id: 'repl'
  filename: join(process.cwd(), 'repl')
  paths: modulePaths

# Resolves a `require()` call. Pass in the name of the module where
# the call was made, and the path that was required.
# Returns an array of: [moduleName, scriptPath]
module.exports = (request, parent = repl) ->
  [_, paths]  = Module._resolveLookupPaths(request, parent)
  filename    = Module._findPath(request, paths)
  throw new Error("Cannot find module: #{request}. Have you run `npm install .` ?") unless filename
  
  # Find package root relative to localModules folder
  dir = filename
  while dir not in invalidDirs and dir not in modulePaths
    dir = dirname(dir)

  # make sure we have a valid directory path
  if dir in invalidDirs
    # possibly a linked module?
    index = filename.lastIndexOf("#{sep}#{request}")
    if index > 0 
      dir = filename.substring(0,index)
      modulePaths.push(dir)
    else
      throw new Error("Load path not found for #{filename}")

  # create the id/scriptPath array
  id = filename.replace("#{dir}#{sep}", '')
  [modulerize(id, filename), filename]

module.exports.paths = (filename) ->
  Module._nodeModulePaths(dirname(filename))

module.exports.modulerize = modulerize
