path      = require('path')
fs        = require('fs')
optimist  = require('optimist')
strata    = require('strata')
compilers = require('./compilers')
pkg       = require('./package')
css       = require('./css')
specs     = require('./specs')
http      = require('http')
httpProxy = require('http-proxy')

argv = optimist.usage([
  '  usage: hem COMMAND',
  '    server  start a dynamic development server',
  '    build   serialize application to disk',
  '    watch   build & watch disk for changes'
  '    test    build and run tests'
].join("\n"))
.alias('p', 'port')
.alias('d', 'debug')
.argv

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
    css:          './css'
    libs:         []
    public:       './public'
    paths:        ['./app']
    dependencies: []
    port:         process.env.PORT or argv.port or 9294
    host:         argv.host or 'localhost'
    useProxy:     argv.useProxy or false
    apiHost:      argv.apiHost or 'localhost'
    apiPort:      argv.apiPort or 8080
    proxyPort:    argv.proxyPort or 8001
    cssPath:      '/application.css'
    jsPath:       '/application.js'

    test:         './test'
    testPublic:   './test/public'
    testPath:     '/test'
    specs:        './test/specs'
    specsPath:    '/specs.js'

  constructor: (options = {}) ->
    @options[key] = value for key, value of options
    @options[key] = value for key, value of @readSlug()

  server: ->
    # make sure the old compiled files are removed so its always dynamic
    @removeOldBuilds()

    # setup strata instance
    strata.use(strata.contentLength)

    # get dynamically compiled javascript/css files
    strata.get(@options.cssPath, @cssPackage().createServer())
    strata.get(@options.jsPath, @hemPackage().createServer())

    # get static public folder
    if fs.existsSync(@options.public)
      strata.use(strata.file, @options.public, ['index.html', 'index.htm'])

    # handle test directory
    if fs.existsSync(@options.testPublic)
      strata.map @options.testPath, (app) =>
        app.get(@options.specsPath, @specsPackage().createServer())
        app.use(strata.file, @options.testPublic, ['index.html', 'index.htm'])

    # start server
    strata.run(port: @options.port, host: @options.host)
  removeOldBuilds: ->
    files = [
      path.join(@options.public, @options.jsPath),
      path.join(@options.public, @options.cssPath),
      path.join(@options.testPublic, @options.specsPath)]
    fs.unlinkSync(filePath) for filePath in files when fs.existsSync(filePath)
    
    # Optionally setup the proxyServer to conditionally route requests.
    # The spine app and the api need to appear to the browser to be coming from
    # the same host and port to avoid crossDomain ajax issues.
    # Ultimately it may be a good idea to configure an api server to accept
    # calls from other domains but sometimes not... 
    if @options.useProxy
      proxy = new httpProxy.RoutingProxy()
      http.createServer (req, res) => 
        console.log 'just stock url', req.url
        startsWithBasePath = new RegExp("^#{@options.baseSpinePath}")
        # baseSpinePath is in config, 
        #application(.js|.css)
        #if url starts with string in the baseSpinePath
          # set req.url -= baseSpinePath
          #pass off to spine host:port
        #else 
          #pass off to apiHost:apiPort
        if startsWithBasePath.test(req.url)
          req.url = req.url.replace(@options.baseSpinePath, '/')
          proxy.proxyRequest(req, res, {
            host: @options.host
            port: @options.port
          })
        else
          proxy.proxyRequest(req, res, {
            host: @options.apiHost
            port: @options.apiPort
          })
      .listen(@options.proxyPort)

  build: (buildTests = false) ->
    source = @hemPackage().compile(not argv.debug)
    fs.writeFileSync(path.join(@options.public, @options.jsPath), source)

    source = @cssPackage().compile()
    fs.writeFileSync(path.join(@options.public, @options.cssPath), source)

    if buildTests
      source = @specsPackage().compile()
      fs.writeFileSync(path.join(@options.testPublic, @options.specsPath), source)

  watch: (callback) ->
    @build()
    for dir in (path.dirname(lib) for lib in @options.libs).concat @options.css, @options.paths, @options.specs
      continue unless fs.existsSync(dir)
      require('watch').watchTree dir, (file, curr, prev) =>
        if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
          console.log "#{file} changed.  Rebuilding."
          @build()
          # TODO: run script here if option is provided

  test: ->
    @build true
    # TODO: run phatomjs and print output

  exec: (command = argv._[0]) ->
    return help() unless @[command]
    @[command]()
    switch command
      when 'build'  then console.log 'Built application'
      when 'watch'  then console.log 'Watching application'
      when 'test'   then console.log 'Testing application'

  # Private

  readSlug: (slug = @options.slug) ->
    # TODO: give error if slug missing
    # TODO: or walk up directory structure to find slug??
    return {} unless slug and fs.existsSync(slug)
    JSON.parse(fs.readFileSync(slug, 'utf-8'))

  cssPackage: ->
    css.createPackage(@options.css)

  hemPackage: ->
    pkg.createPackage(
      dependencies: @options.dependencies
      paths: @options.paths
      libs: @options.libs
    )

  specsPackage: ->
    specs.createPackage(@options.specs)

module.exports = Hem
