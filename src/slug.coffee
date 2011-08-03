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
    dependencies: []
    port: process.env.PORT or 9294
  
  @readSlug: (path) ->
    JSON.parse(fs.readFileSync(path, 'utf-8'))
  
  constructor: (@options = {}) ->
    @options = @readSlug(@options) if typeof @options is 'string'
    @options[key] or= value for key, value of @defaults
    @options.public = resolve(@options.public)
    @addPaths(@options.paths)  
  
  server: ->
    server = express.createServer()
    server.get('/application.js', @createPackage().createServer())  
    server.use(express.static(@options.public))
    server.listen(@options.port)
    
  build: ->
    package = @createPackage().compile()
    package = uglify(package)
    applicationPath = @options.public + '/application.js'
    fs.writeFileSync(applicationPath, package)
    
  static: ->
    server = express.createServer()
    server.use(express.static(@options.public))
    server.listen(@options.port)
    
  addPaths: (paths = []) ->
    require.paths.unshift(path) for path in paths
    
  # Private
  
  createPackage: ->
    require = [].concat(@options.dependencies)
    require.push(@options.main)
    hem.createPackage(
      require: require
      libs:    @options.libs
    )

module.exports = Slug