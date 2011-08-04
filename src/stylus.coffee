{normalize, existsSync, extname, dirname} = require('path')
stylus = require('stylus')
fs     = require('fs')

class Stylus
  constructor: (@path = '') ->
    @path += ".styl" if existsSync(@path + ".styl")
    @path += ".css"  if existsSync(@path + ".css")
    
  compile: (compress = false) ->
    content = fs.readFileSync(@path, 'utf-8')

    result = ""
    stylus(content)
      .include(dirname(@path))
      .set('compress', compress)
      .render((err, css) -> result = css)
    result
    
  createServer: ->
    (req, res, next) =>
      content = @compile()
      res.writeHead 200, 'Content-Type': 'text/css'
      res.end content
      
module.exports = 
  Stylus: Stylus
  createPackage: (path) ->
    new Stylus(path)