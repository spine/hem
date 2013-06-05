connect   = require('connect')
mime      = require('connect').static.mime
httpProxy = require('http-proxy')
http      = require('http')
fs        = require('fs')
server    = {}

# ------- Public Functions

server.start = (packages, options) ->
    app = connect()
    app.use(server.middleware(app, packages, options))
    http.createServer(app).listen(options.port, options.host)

# eventually just pass in routes and server options
server.middleware = (app, packages, options) ->

  # determine if there is any static routes to add
  for pkg in packages
    if pkg.url and !!server.VERBOSE
      console.log "Map package '#{pkg.name}' to #{pkg.url}"
    if pkg.static
      options.routes.push pkg.static

  # setup static and proxy middleware
  for route in options.routes
    url   = Object.keys(route)[0]
    value = route[url]
    # setup static route
    if (typeof value is 'string')
      if fs.existsSync(value)
        console.log "Map directory '#{value}' to #{url}" if !!server.VERBOSE
        app.use(url, connect.static(value))
      else
        console.log "ERROR: The folder #{value} does not exist."
        process.exit(1)
    # setup proxy route
    else if value.host
      console.log "Proxy requests from #{url} to #{value.host}" if !!server.VERBOSE
      app.use(url, createRoutingProxy(value))
    else
      throw new Error("Invalid route configuration for #{url}")

  # return the custom middleware for connect to use
  return (req, res, next) ->

    # get url path
    url = require("url").parse(req.url)?.pathname.toLowerCase() or ""

    # loop over pkgs and call compile when there is a match
    if url.match(/\.js|\.css/)
      for pkg in packages
        # TODO: get non versioned url here??
        if pkg.isMatchingUrl(url)
          # TODO: keep (and return) in memory build if there hasn't been any changes??
          str = pkg.compile(!!server.DEBUG)
          res.charset = 'utf-8'
          res.setHeader('Content-Type', mime.lookup(pkg.target))
          res.setHeader('Content-Length', Buffer.byteLength(str))
          res.end((req.method is 'HEAD' and null) or str)
          return
    # continue to next middleware
    next()

# ------- Private Functions

createRoutingProxy = (options = {}) ->
  proxy = new httpProxy.RoutingProxy()
  # additional options
  options.hostPath or= ""
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
    req.url = "#{options.hostPath}#{req.url}"
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
