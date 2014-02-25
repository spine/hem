path   = require('path')
fs     = require('fs-extra')
utils  = {}

# check for windows :o(...
isWin = !!require('os').platform().match(/^win/)

utils.flatten = flatten = (array, results = []) ->
  for item in array
    if Array.isArray(item)
      flatten(item, results)
    else if item
      results.push(item)
  results

utils.arrayToString = (value) ->
  if Array.isArray(value)
    result = ""
    for line in value
      result += line + "\n"
    result
  else
    value

utils.removeDuplicateValues = (array) ->
  newArray = []
  for value in array
    if value not in newArray
      newArray.push(value)
  newArray

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
  require("../assets/" + asset)

utils.copyFile = (from, to) ->
  # make sure target files exists
  fs.createFileSync(to)
  # constants
  BUF_LENGTH = 64 * 1024
  _buff = new Buffer(BUF_LENGTH)
  # perform copy
  fdr = fs.openSync(from, 'r')
  fdw = fs.openSync(to, 'w')
  bytesRead = 1
  pos = 0
  while bytesRead > 0
    bytesRead = fs.readSync(fdr, _buff, 0, BUF_LENGTH, pos)
    fs.writeSync(fdw, _buff, 0, bytesRead)
    pos += bytesRead
  fs.closeSync(fdr)
  fs.closeSync(fdw)

utils.isDirectory = (dir) ->
  try
    stats = fs.lstatSync(dir)
    stats.isDirectory()
  catch e
    false

utils.requireDirectory = (directory) ->
  directory = path.resolve(directory)
  fs.readdirSync(directory).reduce (hash, file) ->
    file_path = path.join(directory, file)
    file_name = file.substring(0, file.lastIndexOf('.'))
    file_extension = file.substring(file.lastIndexOf('.'))
    if file_extension not in ['.coffee', '.js']
      return hash
    else if file_name is 'index' and typeof require(file_path) is 'object'
      for key, value of require(file_path)
        hash[key] = value
    else
      hash[file_name] = require(file_path)
    return hash
  , {}

# ------ Simple templating function

utils.tmplStr  = (str, data) ->
  require('mustache').render(str, data)

utils.tmplFile = (file, data) ->
  template = utils.loadAsset("#{str}.tmpl")
  utils.tmplStr(template, data)

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
  result = clean(paths, path.sep, true)
  # deal with windows paths :o(...
  if isWin or true
    cleanPath = new RegExp /\//g
    result = result.replace(cleanPath, path.sep)
  result

utils.cleanRoute = (routes...) ->
  clean(routes, "/")

module.exports = utils
