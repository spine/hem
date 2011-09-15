Module = require('module')
{join, extname, dirname, basename, resolve} = require('path')

isAbsolute = (path) -> /^\//.test(path)

# Normalize paths and remove extensions
# to create valid CommonJS module names
modulerize = (id, filename = id) -> 
  ext = extname(filename)
  join(dirname(id), basename(id, ext))

# Resolves a `require()` call. Pass in the name of the module where
# the call was made, and the path that was required. 
# Returns an array of: [moduleName, scriptPath]

localPaths  = Module._nodeModulePaths(process.cwd())
modulePaths = module.paths.concat(localPaths)
modulePaths = modulePaths.sort (a, b) -> (b.length - a.length)

repl =
  id: 'repl'
  filename: join(process.cwd(), 'repl')
  paths: modulePaths

module.exports = (request, parent = repl) ->
  [_, paths]  = Module._resolveLookupPaths(request, parent)  
  filename    = Module._findPath(request, paths)
  dir         = filename
  
  # Find package root
  
  while dir and modulePaths.indexOf(dir) is -1 
    dir = dirname(dir)
  id = filename.replace("#{dir}/", '')

  [modulerize(id, filename), filename]
  
module.exports.paths = (filename) ->
  Module._nodeModulePaths(dirname(filename))
  
module.exports.modulerize = modulerize