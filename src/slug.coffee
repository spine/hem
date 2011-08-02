connect  = require('connect')
fs       = require('fs')
uglify   = require('uglify-js')
hem      = require('./hem')

class Slug
  @readSlug: (path) ->
    JSON.parse(fs.writeFileSync(path or './slug.json'))
  
  @server: (options = {}) ->
    server = connect.createServer()
    server.use(connect.static(options.public or './public'))
    server.get('/application.js', @package(options).createServer())  
    port = process.env.PORT or options.port or 9294
    server.serve(port)
    port
    
  @build: (options = {}) ->
    slug = @package(options).compile()
    slug = uglify(slug)
    applicationPath = (options.public or './public') + '/application.js'
    fs.writeFileSync(applicationPath, slug)
    
  @static: (options = {}) ->
    server = connect.createServer()
    server.use(connect.static(options.public or './public'))
    port = process.env.PORT or options.port or 9294
    server.serve(port)
    port
    
  # Private
  
  @package: (options = {}) ->
    hem.createPackage(
      paths: options.main or './app/index'
      libs:  options.libs or './lib'
    )

module.exports = Slug