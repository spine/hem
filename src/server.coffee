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
  if options.host is "*"
    http.createServer(app).listen(options.port)
  else 
    http.createServer(app).listen(options.port, options.host)
  return app

server.middleware = (hem) ->
  backend = connect()
  options = hem.options.hem
  statics = []

  # create array of static routes
  for route, value of options?.static
    statics.push
      url  : route
      path : value

  # determine if there is any dynamic or static routes to add
  for app in hem.apps

    # if verbose then print our mappings and apply the baseAppRoute if present
    log.info "> Apply route mappings for application: <green>#{app.name}</green>"
    for pkg in app.packages
      if options.baseAppRoute
        pkg.route = utils.cleanRoute(options.baseAppRoute, pkg.route)
      log.info " - Mapping route  <yellow>#{pkg.route}</yellow> to <yellow>#{pkg.target}</yellow>"

    # loop over potential static routes and add them to main route array
    for route in app.static
      if options.baseAppRoute
        route.url = utils.cleanRoute(options.baseAppRoute, route.url)
      log.info " - Mapping static <yellow>#{route.url}</yellow> to <yellow>#{route.path}</yellow>"
      statics.push(route)

  # setup separate connect app for static routes and proxy middleware
  for route in statics
    # make sure path exists
    unless fs.existsSync(route.path)
      log.errorAndExit "The resource <yellow>#{route.path}</yellow> not found for static mapping <yellow>#{route.url}</yellow>"
    # test if file is directory or file....
    if fs.lstatSync(route.path).isDirectory()
      backend.use(route.url, checkForRedirect())
      backend.use(route.url, connect.static(route.path) )
    else
      backend.use route.url, do (route) ->
        (req, res) ->
          fs.readFile route.path, (err, data) ->
            if err
              res.writeHead(404)
              res.end(JSON.stringify(err))
            else
              res.writeHead(200)
              res.end(data)

  # setup proxy route
  for route, value of options.proxy
    display = "#{value.host}:#{value.port or 80}#{value.path}"
    log.info "> Proxy requests <yellow>#{route}</yellow> to <yellow>#{display}</yellow>"
    backend.use(route, createRoutingProxy(value, "#{options.host}:#{options.port}"))

  # return the custom middleware for connect to use
  return (req, res, next) ->
    # get url path
    url = require("url").parse(req.url)?.pathname.toLowerCase() or ""
    
    # loop over applications and call compile when there is a match
    if url.match(/(\.js|\.css)$/)
      for app in hem.apps
        if pkg = app.isMatchingRoute(url)
          str = pkg.build()
          res.charset = 'utf-8'
          res.setHeader('Content-Type', mime.lookup(pkg.target))
          res.setHeader('Content-Length', Buffer.byteLength(str))
          res.end((req.method is 'HEAD' and null) or str)
          return

    # pass request to static connect app to handle static/proxy requests
    backend.handle(req, res, next)

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

createRoutingProxy = (options, returnHost) ->
  # handle https differently
  if options.https
    routingProxyOptions = {target: {https:true}}
    defaultPort = 443
  else
    routingProxyOptions = {}
    defaultPort = 80
  # create proxy
  proxy = new httpProxy.RoutingProxy(routingProxyOptions)
  # set options
  options.path or= ""
  options.port or= defaultPort
  options.patchRedirect or= true
  # handle redirects
  if options.patchRedirect
    proxy.once "start", (req, res) ->
      # get the requesting hostname and port
      patchServerResponseForRedirects(options.host, returnHost)
  # return function used by connect to access proxy
  return (req, res, next) ->
    req.url = "#{options.path}#{req.url}"
    req.headers.host = options.host
    proxy.proxyRequest(req, res, options)

patchServerResponseForRedirects = (fromHost, returnHost) ->
  writeHead = http.ServerResponse.prototype.writeHead
  http.ServerResponse.prototype.writeHead = (status) ->
    headers =  @_headers
    if status in [301,302]
      oldLocation = new RegExp("s?:\/\/#{fromHost}:?[0-9]*")
      newLocation = "://#{returnHost}"
      headers.location = headers.location.replace(oldLocation,newLocation)
    if 'set-cookie' of headers
      newSetCookie = []
      for cookie in headers['set-cookie']
        # remove the secure setting, so we can get cookie setting to work
        newSetCookie.push cookie.replace /; Secure; HttpOnly/, ''
      headers['set-cookie'] = newSetCookie
    return writeHead.apply(@, arguments)

# export the public functions
module.exports = server
