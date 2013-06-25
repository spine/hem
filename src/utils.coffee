sty   = require('sty')
path  = require('path')
fs    = require('fs')
utils = {}

utils.flatten = flatten = (array, results = []) ->
  for item in array
    if Array.isArray(item)
      flatten(item, results)
    else
      results.push(item)
  results

utils.toArray = (value = []) ->
  if Array.isArray(value) then value else [value]

utils.startsWith = (str, value) ->
  str?.slice(0, value.length) is value

utils.endsWith = (str, value) ->
  str?.slice(-value.length) is value

utils.extend = extend = (a, b) ->
  for x of b
    if typeof b[x] is 'object' and not Array.isArray(b[x])
      a[x] or= {}
      extend(a[x], b[x])
    else
      a[x] = b[x]
  return a

utils.loadAsset = (asset) ->
  return require("../assets/" + asset)

utils.isDirectory = (dir) ->
  try
    stats = fs.lstatSync(dir)
    stats.isDirectory()
  catch e
    false

# ------ Formatting urls and folder paths

clean = (values, sep, trimStart = false) ->
  result = ""
  for value in values when value
    result = result + sep + value
  # clean duplicate sep
  regexp = new RegExp "#{sep}+","g"
  result = result.replace(regexp, sep)
  # trim the starting path sep if there is one
  if trimStart and utils.startsWith(result, sep)
    result = result.slice(sep.length)
  # make sure doesn't end in sep
  if utils.endsWith(result, sep)
    result = result.slice(0, -sep.length)
  result

utils.cleanPath = (paths...) ->
  clean(paths, path.sep, true)

utils.cleanRoute = (routes...) ->
  clean(routes, "/")



# ------ Logging Helpers

utils.log = (message) ->
  console.log sty.parse(message)

utils.info = (message) ->
  console.log sty.parse(message) if @VERBOSE

utils.error = (message) ->
  console.log "#{sty.red 'ERROR:'} #{sty.parse(message)}"

utils.errorAndExit = (error) ->
  utils.error(error)
  process.exit(1)

utils.parse = (message) -> 
  sty.parse(message)

module.exports = utils
