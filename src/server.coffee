connect   = require('connect')
mime      = require('connect').static.mime
httpProxy = require('http-proxy')
http      = require('http')
fs        = require('fs')
utils     = require('./utils')
log       = require('./log')

# ------- Public Functions

server = {}

server.start = (hem) ->
  # create app to configure
  app = connect()
  app.use(server.middleware(hem))
  # start server
  options = hem.options.hem
  http.createServer(app).listen(options.port, options.host)

server.middleware = (hem) ->
  statics = connect()
  options = hem.options.hem

  # determine if there is any dynamic or static routes to add
  for app in hem.apps

    # if verbose then print our mappings and apply the baseAppRoute if present
    log.info "> Apply route mappings for application: <green>#{app.name}</green>"
    for name, pkg of app.packages
      pkg.route = utils.cleanRoute(options.baseAppRoute, pkg.route) if options.baseAppRoute
      log.info " - Mapping route  <yellow>#{pkg.route}</yellow> to <yellow>#{pkg.target}</yellow>"
    for route, value of app.static
      route = utils.cleanRoute(options.baseAppRoute, route) if options.baseAppRoute
      log.info " - Mapping static <yellow>#{route}</yellow> to <yellow>#{value}</yellow>"

    # add static routes to main options.route collection
    if app.static
      options.routes = utils.extend(app.static, options.routes)

  # setup separate connect app for static routes and proxy middleware
  for route, value of options.routes
    if fs.existsSync(value)
      # test if file is directory or file....
      if fs.lstatSync(value).isDirectory()
        statics.use(route, checkForRedirect())
        statics.use(route, connect.static(value) )
      else
        statics.use route, do (value) ->
          (req, res) ->
            fs.readFile value, (err, data) ->
              if err
                res.writeHead(404)
                res.end(JSON.stringify(err))
                return
              res.writeHead(200)
              res.end(data)
    else
      log.errorAndExit "The folder <yellow>#{value}</yellow> does not exist for static mapping <yellow>#{route}</yellow>"

  # setup proxy route
  for route, value of options.proxy
    display = "#{value.host}:#{value.port or 80}#{value.path}"
    log.info "> Proxy requests <yellow>#{route}</yellow> to <yellow>#{display}</yellow>"
    statics.use(route, createRoutingProxy(value))

  # return the custom middleware for connect to use
  return (req, res, next) ->
    # get url path
    url = require("url").parse(req.url)?.pathname.toLowerCase() or ""
    
    # loop over applications and call compile when there is a match
    if url.match(/(\.js|\.css)$/)
      for app in hem.apps
        if pkg = app.isMatchingRoute(url)
          # TODO: keep (and return) in memory build if there hasn't been any changes??
          str = pkg.build(false)
          res.charset = 'utf-8'
          res.setHeader('Content-Type', mime.lookup(pkg.target))
          res.setHeader('Content-Length', Buffer.byteLength(str))
          res.end((req.method is 'HEAD' and null) or str)
          return

    # pass request to static connect app to handle static/proxy requests
    statics.handle(req, res, next)

# ------- Private Functions

checkForRedirect = () ->
  return (req, res, next) ->
    pathname = require("url").parse(req.originalUrl).pathname
    if (req.url is "/" and not utils.endsWith(pathname,"/"))
      pathname += '/'
      res.statusCode = 301
      res.setHeader('Location', pathname)
      res.end('Redirecting to ' + pathname)
    else
      next()

createRoutingProxy = (options) ->
  proxy = new httpProxy.RoutingProxy()
  # set options
  options.path or= ""
  options.port or= 80
  options.patchRedirect or= true
  # handle redirects
  if options.patchRedirect
    proxy.once "start", (req, res) ->
      # get the requesting hostname and port
      returnHost = req.headers.host
      patchServerResponseForRedirects(options.host, returnHost)
  # return function used by connect to access proxy
  return (req, res, next) ->
    req.url = "#{options.path}#{req.url}"
    proxy.proxyRequest(req, res, options)

patchServerResponseForRedirects = (fromHost, returnHost) ->
  writeHead = http.ServerResponse.prototype.writeHead
  http.ServerResponse.prototype.writeHead = (status) ->
    if status in [301,302]
      headers =  @_headers
      oldLocation = new RegExp(":\/\/#{fromHost}:?[0-9]*")
      newLocation = "://#{returnHost}"
      headers.location = headers.location.replace(oldLocation,newLocation)
    return writeHead.apply(@, arguments)

# export the public functions
module.exports = server
