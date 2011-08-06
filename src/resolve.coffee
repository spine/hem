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

repl =
  id: 'repl'
  filename: join(process.cwd(), 'repl')
  paths: module.paths

module.exports = (request, parent = repl) ->
  [id, paths] = Module._resolveLookupPaths(request, parent)  
  filename    = Module._findPath(request, paths)
  
  unless filename
    throw new Error("Cannot find module '#{request}'")
    
  if isAbsolute(id)
    paths = paths.sort (a, b) -> (b.length - a.length)
    for path in paths when id.indexOf(path) != -1
      id = id.replace(path + '/', '')
      break
  [modulerize(id, filename), filename]
  
module.exports.paths = (filename) ->
  Module._nodeModulePaths(dirname(filename))
  
module.exports.modulerize = modulerize