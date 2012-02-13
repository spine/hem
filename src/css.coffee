{resolve} = require('path')
compilers = require('./compilers')
{toArray} = require('./utils')

class CSS
  constructor: (paths) ->
    @paths = toArray(paths).map(@try_resolve).filter(((path) -> !!path))

  compile: ->
    @paths.map((path) ->
      delete require.cache[path]
      require(path)
    ).join('')

  
  createServer: ->
    (req, res, next) =>
      content = @compile()
      res.writeHead 200, 'Content-Type': 'text/css'
      res.end content

  try_resolve: (file) ->
    try
      file = require.resolve(resolve(file))
      return file
    catch e
      console.log(e)
    return null

      
module.exports = 
  CSS: CSS
  createPackage: (path) ->
    new CSS(path)
