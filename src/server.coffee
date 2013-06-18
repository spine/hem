connect   = require('connect')
mime      = require('connect').static.mime
http      = require('http')
fs        = require('fs')
utils     = require('./utils')
httpProxy = require('http-proxy')
server    = {}

# ------- Public Functions

server.start = (hem, options) ->
    app = connect()
    app.use(server.middleware(hem, options))
    http.createServer(app).listen(options.port, options.host)

server.middleware = (hem, options) ->
  # determine if there is any dynamic or static routes to add
  for hemapp in hem.apps
    if utils.VERBOSE
      utils.log "> Apply route mappings for application: <green>#{hemapp.name}</green>"
      for pkg in hemapp.packages
        utils.log "- Mapping route  <yellow>#{pkg.route}</yellow> to <yellow>#{pkg.target}</yellow>"
    if hemapp.static
      options.routes = utils.extend(hemapp.static, options.routes)

  # setup static routes and proxy middleware
  statics = connect()
  for route, value of options.routes
    # setup static route
    if (typeof value is 'string')
      if fs.existsSync(value)
        utils.verbose "- Mapping static <yellow>#{route}</yellow> to <yellow>#{value}</yellow>" 
        statics.use(route, connect.static(value))
      else
        utils.errorAndExit "The folder #{value} does not exist."
    # setup proxy route
    else if value.host
      utils.verbose "- Proxy requests <yellow>#{route}</yellow> to <yellow>#{value.host}:#{value.port or 80}#{value.hostPath}</yellow>" 
      statics.use(route, createRoutingProxy(value))
    else
      utils.errorAndExit("Invalid route configuration for <yellow>#{route}</yellow>")

  # return the custom middleware for connect to use
  return (req, res, next) ->
    # get url path
    url = require("url").parse(req.url)?.pathname.toLowerCase() or ""
    
    # loop over hem applications and call compile when there is a match
    if url.match(/\.js|\.css/)
      for hemapp in hem.apps
        if pkg = hemapp.isMatchingRoute(url)
          # TODO: keep (and return) in memory build if there hasn't been any changes??
          str = pkg.build()
          res.charset = 'utf-8'
          res.setHeader('Content-Type', mime.lookup(pkg.target))
          res.setHeader('Content-Length', Buffer.byteLength(str))
          res.end((req.method is 'HEAD' and null) or str)
          return
    
    # check static content
    statics.handle(req, res, next)


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