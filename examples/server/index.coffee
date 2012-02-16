strata = require 'strata'

router = new strata.Router

exports.router = router

router.get '/item', (env, callback) ->
  callback 200, {}, '{"name":"Somebody", "email": "somebody@example.com"}'

exports.initOnce = (app) ->
  app.use strata.commonLogger
  app.use strata.contentType, 'text/html'
  app.use strata.contentLength
