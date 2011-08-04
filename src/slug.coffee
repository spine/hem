{resolve}    = require('path')
express      = require('express')
fs           = require('fs')
hem          = require('./hem')
stylus       = require('./stylus')

class Slug
  defaults:
    slug: './slug.json'
    main: './app/index'
    css:  './css/index'
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
    server.get('/application.css', @stylusPackage().createServer())
    server.get('/application.js', @hemPackage().createServer())  
    server.use(express.static(@options.public))
    server.listen(@options.port)
    
  build: ->
    package = @hemPackage().compile(true)
    applicationPath = @options.public + '/application.js'
    fs.writeFileSync(applicationPath, package)
    
    package = @stylusPackage().compile(true)
    applicationPath = @options.public + '/application.css'
    fs.writeFileSync(applicationPath, package)
    
  static: ->
    server = express.createServer()
    server.use(express.static(@options.public))
    server.listen(@options.port)
    
  addPaths: (paths = []) ->
    require.paths.unshift(path) for path in paths
    
  # Private
  
  stylusPackage: ->
    stylus.createPackage(@options.css)
  
  hemPackage: ->
    require = [].concat(@options.dependencies)
    require.push(@options.main)
    hem.createPackage(
      require: require
      libs:    @options.libs
    )

module.exports = Slug