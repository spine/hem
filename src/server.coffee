connect = require('connect')
mime    = require('connect').static.mime
http    = require('http')
fs      = require('fs')
utils   = require('./utils')
server  = {}

# ------- Public Functions

server.start = (hemapps, options) ->
    app = connect()
    app.use(server.middleware(app, hemapps, options))
    http.createServer(app).listen(options.port, options.host)

server.middleware = (app, hemapps, options) ->

  # determine if there is any dynamic or static routes to add
  for hemapp in hemapps
    if hemapp.url and utils.VERBOSE
      for pkg in hemapp.packages
        utils.log "Map application target '#{pkg.target}' to #{pkg.route}"
    if hemapp.static
      options.routes = utils.extend(options.routes, hemapp.static)

  # setup static routes and proxy middleware
  for route in options.routes
    url   = Object.keys(route)[0]
    value = route[url]
    # setup static route
    if (typeof value is 'string')
      if fs.existsSync(value)
        utils.verbose "Map directory '#{value}' to #{url}" 
        app.use(url, connect.static(value))
      else
        utils.errorAndExit "The folder #{value} does not exist."
    # setup proxy route
    else if value.host
      utils.verbose "Proxy requests from #{url} to #{value.host}" 
      app.use(url, createRoutingProxy(value))
    else
      throw new Error("Invalid route configuration for #{url}")

  # return the custom middleware for connect to use
  return (req, res, next) ->

    # get url path
    url = require("url").parse(req.url)?.pathname.toLowerCase() or ""

    # loop over hem applications and call compile when there is a match
    if url.match(/\.js|\.css/)
      for hemapp in hemapps
        if pkg = hemapp.isMatchingRoute(url)
          # TODO: keep (and return) in memory build if there hasn't been any changes??
          str = pkg.compile(not debug)
          res.charset = 'utf-8'
          res.setHeader('Content-Type', mime.lookup(pkg.target))
          res.setHeader('Content-Length', Buffer.byteLength(str))
          res.end((req.method is 'HEAD' and null) or str)
          return
    # continue to next middleware
    next()

# ------- Private Functions

createRoutingProxy = (options = {}) ->
  proxy = new require('http-proxy').RoutingProxy()
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
