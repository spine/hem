{resolve}    = require('path')
express      = require('express')
fs           = require('fs')
hem          = require('./hem')
stylus       = require('./stylus')
path         = require('path')
watch        = require('watch')
console      = require('console')

class Slug
  defaults:
    slug:         './slug.json'
    css:          './css/index'
    libs:         []
    public:       './public'
    paths:        ['./app']
    dependencies: []
    port:         process.env.PORT or 9294
  
  @readSlug: (path) ->
    JSON.parse(fs.readFileSync(path, 'utf-8'))
  
  constructor: (@options = {}) ->
    @options = @readSlug(@options) if typeof @options is 'string'
    @options[key] or= value for key, value of @defaults
    @options.public = resolve(@options.public)
  
  server: ->
    server = express.createServer()
    server.get('/application.css', @stylusPackage().createServer())
    server.get('/application.js', @hemPackage().createServer())  
    server.use(express.static(@options.public))
    server.listen(@options.port)
    
  build: ->
    try
      package = @hemPackage().compile(true)
      applicationPath = @options.public + '/application.js'
      fs.writeFileSync(applicationPath, package)
      
      package = @stylusPackage().compile(true)
      applicationPath = @options.public + '/application.css'
      fs.writeFileSync(applicationPath, package)
    catch error
      console.error error.stack
      
  watch: -> 
    @build() 
    for dir in [path.dirname @options.css].concat @options.paths, @options.libs
      watch.watchTree dir, (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          console.log "#{file} changed.  Rebuilding."
          @build()
    
  static: ->
    server = express.createServer()
    server.use(express.static(@options.public))
    server.listen(@options.port)
    
  # Private
  
  stylusPackage: ->
    stylus.createPackage(@options.css)
  
  hemPackage: ->
    hem.createPackage(
      dependencies: @options.dependencies
      paths: @options.paths
      libs: @options.libs
    )

module.exports = Slug