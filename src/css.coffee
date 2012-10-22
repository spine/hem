{resolve} = require('path')
fs        = require('fs')
compilers = require('./compilers')

class CSS
  constructor: (config = {}) ->
    try
      @path   = require.resolve(resolve(config.path))
      @target = config.target
    catch e
    
  compile: ->
    return unless @path
    delete require.cache[@path]
    require(@path)

  unlink: ->
    fs.unlinkSync(@target) if fs.existsSync(@target)
  
  # TODO: move this to a separate middleware class, pass in package to call compile and content type on..
  middleware: (req, res, next) =>
    str = @compile()
    contentType = "text/css"
    res.charset = 'utf-8'
    res.setHeader('Content-Type', contentType)
    res.setHeader('Content-Length', Buffer.byteLength(str))
    res.end((req.method is 'HEAD' and null) or str)

module.exports =
  CSS: CSS
  createPackage: (config) ->
    new CSS(config)
