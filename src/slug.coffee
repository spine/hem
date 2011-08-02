connect  = require('connect')
fs       = require('fs')
uglify   = require('uglify-js')
hem      = require('./hem')

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
    @options[key] or= value for key, value in @defaults
    @addPaths(@options.paths)
  
  readSlug: (path) ->
    JSON.parse(fs.writeFileSync(path or @options.slug))
  
  server: ->
    server = connect.createServer()
    server.use(connect.static(@options.public))
    server.get('/application.js', @createPackage().createServer())  
    server.serve(@options.port)
    @options.port
    
  build: ->
    slug = @createPackage().compile()
    slug = uglify(slug)
    applicationPath = @options.public + '/application.js'
    fs.writeFileSync(applicationPath, slug)
    
  static: ->
    server = connect.createServer()
    server.use(connect.static(@options.public))
    server.serve(@options.port)
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