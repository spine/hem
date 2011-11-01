path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
express   = require('express')
compilers = require('./compilers')
package   = require('./package')
css       = require('./css')

optimist.usage([
  '  usage: hem COMMAND',
  '    server  start a dynamic development server',
  '    build   serialize application to disk',
  '    watch   build & watch disk for changes'
].join("\n")).alias('p', 'port')

argv = optimist.argv

help = ->
  optimist.showHelp()
  process.exit()

class Hem
  @exec: (command, options) ->
    (new @(options)).exec(command)
  
  @include: (props) ->
    @::[key] = value for key, value of props
    
  compilers: compilers
    
  options: 
    slug:         './slug.json'
    css:          './css/index'
    libs:         []
    public:       './public'
    paths:        ['./app']
    dependencies: []
    port:         process.env.PORT or argv.port or 9294
    cssPath:      '/application.css'
    jsPath:       '/application.js'

  constructor: (options = {}) ->
    @options[key] = value for key, value of options    
    @options[key] = value for key, value of @readSlug()
    
    @express = express.createServer()
    
  server: ->
    @express.get(@options.cssPath, @cssPackage().createServer())
    @express.get(@options.jsPath, @hemPackage().createServer())
    @express.use(express.static(@options.public))
    @express.listen(@options.port)
    
  build: ->
    package = @hemPackage().compile()
    fs.writeFileSync(path.join(@options.public, @options.jsPath), package)
    
    package = @cssPackage().compile()
    fs.writeFileSync(path.join(@options.public, @options.cssPath), package)

  watch: ->
    @build() 
    for dir in [path.dirname @options.css].concat @options.paths, @options.libs
      require('watch').watchTree dir, (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          console.log "#{file} changed.  Rebuilding."
          @build()
          
  exec: (command = argv._[0]) ->
    return help() unless @[command]
    @[command]()
    console.log switch command
      when 'server' then "Starting server on: #{@options.port}"
      when 'build'  then 'Built application'
      when 'watch'  then 'Watching application'

  # Private
    
  readSlug: (slug = @options.slug) -> 
    return {} unless slug and path.existsSync(slug)
    JSON.parse(fs.readFileSync(slug, 'utf-8'))
    
  cssPackage: ->
    css.createPackage(@options.css)

  hemPackage: ->
    package.createPackage(
      dependencies: @options.dependencies
      paths: @options.paths
      libs: @options.libs
    )

module.exports = Hem