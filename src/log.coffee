sty   = require('sty')

# ------ Logging Helpers

log = (message, parse = true) ->
  console.log(parse and sty.parse(message) or message)

log.info = (message, parse = true) ->
  console.log(parse and sty.parse(message) or message) if @VERBOSE

log.error = (message, parse = true) ->
  console.log "#{sty.red 'ERROR:'} #{parse and sty.parse(message) or message}"

log.errorAndExit = (error, parse = true) ->
  log.error(error, parse)
  process.exit(1)

log.parse = (message) ->
  sty.parse(message)

module.exports = log
