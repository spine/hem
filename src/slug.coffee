{resolve}    = require('path')
express      = require('express')
fs           = require('fs')
uglify       = require('uglify-js')
hem          = require('./hem')

class Slug
  defaults:
    slug: './slug.json'
    main: './app/index'
    libs: []
    public: './public'
    paths: ['./app']
    port: process.env.PORT or 9294
  
  constructor: (@options = {}) ->
    @options = @readSlug(@options) if typeof @options is 'string'
    @options[key] or= value for key, value of @defaults
    @options.public = resolve(@options.public)
    @addPaths(@options.paths)
  
  readSlug: (path) ->
    JSON.parse(fs.readFileSync(path or @options.slug, 'utf-8'))
  
  server: ->
    server = express.createServer()
    server.use(express.static(@options.public))
    server.get('/application.js', @createPackage().createServer())  
    server.listen(@options.port)
    @options.port
    
  build: ->
    package = @createPackage().compile()
    package = uglify(package)
    applicationPath = @options.public + '/application.js'
    fs.writeFileSync(applicationPath, package)
    
  static: ->
    server = express.createServer()
    server.use(express.static(@options.public))
    server.listen(@options.port)
    @options.port
    
  addPaths: (paths = []) ->
    require.paths.unshift(path) for path in paths
    
  # Private
  
  createPackage: ->
    hem.createPackage(
      require: @options.main
      libs:    @options.libs
    )

module.exports = Slug