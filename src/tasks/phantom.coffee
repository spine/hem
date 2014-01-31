fs    = require('fs')
path  = require('path')
utils = require('../utils')
Log   = require('../log')

# private functions

updateVersionInAppFiles = (files, builds, value) ->
  # TODO: use node-glob!!
  for file in files
    Log "- updating file <yellow>#{file}</yellow> with version: <b>#{value}</b>"
    data = fs.readFileSync(file, 'utf8')
    # match all target in packages
    for key, build of builds
      data = updateVersionInData(data, value, build)
    fs.writeFileSync(file, data)

updateVersionInData = (data, value, build) ->
  ext     = path.extname(pkg.target)
  name    = path.basename(pkg.target, ext)
  match   = new RegExp("=(\"|')(.*/?)#{name}[^\"']?#{ext}(\"|')")
  replace = "=$1$2#{name}.#{value}#{ext}$3"
  # perform replace
  if data.match(match)
    Log "> found target: #{pkg.target}"
    data.replace(match, replace)
  else
    data

# handle versioning based on package.json version (default)

versionTypes =
  package: ->
      JSON.parse(fs.readFileSync('./package.json', 'utf8')).version


task = ->
  # initialize version type
  @type or= 'package'
  unless versionTypes[@type]
    Log.errorAndExit "Invalid version type #{@type} for job #{@job.name}"

  return (params) ->

    update = (type) ->
      getVersion = versionTypes[type]
      updateVersionInAppFiles(@src, @job.app.tasks.build, getVersion())

    trim = (url) ->
      url.replace(/^([^.]+).*(\.css|\.js)$/i, "$1$2")

    # if supplied a param, then trim any potential versioning
    if params.route
      params.route = trim(params.route)
    # else perform the versioning function
    else
      update(@type)

# TODO: other types that could be made
# 1) based on git commits/tags
# 2) backed on jenkinds builds or env values
# 3) Allow build/version to happen with one command (deploy)

module.exports = task
