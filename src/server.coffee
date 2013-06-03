connect   = require('connect')
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

  # TODO: flag to not make the files dynamically compiled, skip mapping
  # setup dynamic targets first
  for pkg in packages
    # determine url if its not already set
    pkg.url or= determineUrlFromRoutes(pkg, options.routes)
    # exit if pkg.url isn't defined
    if not pkg.url
      throw new Error "Unable to determine url mapping for package: #{pkg.name}"
    console.log "Map package '#{pkg.name}' to #{pkg.url}" if !!server.VERBOSE

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

    # strip out any potential versioning 
    # if @vertype
      # url = @vertype.trimVersion(url)

    # loop over pkgs and call compile when there is a match
    if url.match(/\.js|\.css/)
      for pkg in packages
        # TODO: get non versioned url here??
        if url is pkg.url
          # TODO: keep (and return) in memory build if there hasn't been any changes??
          str = pkg.compile(!!server.DEBUG)
          res.charset = 'utf-8'
          res.setHeader('Content-Type', pkg.contentType)
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

determineUrlFromRoutes = (pkg, routes) ->
  bestMatch = {}
  for route in routes
    url = Object.keys(route)
    dir = route[url]
    # compare against package target
    if pkg.target.indexOf(dir) == 0 and (!bestMatch.url or bestMatch.dir.length < dir.length)
      bestMatch.url = url + pkg.target.slice(dir.length)
      bestMatch.dir = dir
  bestMatch.url.toLowerCase()

# export the start function
module.exports = server
