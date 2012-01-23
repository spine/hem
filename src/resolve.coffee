Module = require('module')
{join, extname, dirname, basename, resolve} = require('path')

isAbsolute = (path) -> /^\//.test(path)

# Normalize paths and remove extensions
# to create valid CommonJS module names
modulerize = (id, filename = id) -> 
  ext = extname(filename)
  modName = join(dirname(id), basename(id, ext))
  modName.replace('\\', '/');

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
  dir         = filename
  
  throw("Cannot find module: #{request}. Have you run `npm install .` ?") unless filename
    
  # Find package root relative to localModules folder
  while dir not in invalidDirs and dir not in modulePaths
    dir = dirname(dir)
  
  throw("Load path not found for #{filename}") if dir in invalidDirs
    
  id = filename.replace("#{dir}/", '')

  [modulerize(id, filename), filename]
  
module.exports.paths = (filename) ->
  Module._nodeModulePaths(dirname(filename))
  
module.exports.modulerize = modulerize