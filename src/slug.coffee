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
    package = @hemPackage().compile(true)
    applicationPath = @options.public + '/application.js'
    fs.writeFileSync(applicationPath, package)
    
    package = @stylusPackage().compile(true)
    applicationPath = @options.public + '/application.css'
    fs.writeFileSync(applicationPath, package)
      
  watch: -> 
    @build() 
    for dir in [path.dirname @options.css].concat @options.paths, @options.libs
      watch.watchTree dir, {ignoreDotFiles:true}, (file,o,n) =>
        if o and +o.mtime != +n.mtime
          console.log "#{file} changed.  Rebuilding."
          try
            @build()
          catch error
            console.dir error.toString()
    
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