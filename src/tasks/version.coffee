fs    = require('fs')
path  = require('path')
utils = require('../utils')
Log   = require('../log')

# private functions

updateFiles = (files, builds, value) ->
  # TODO: use node-glob!!
  for file in files
    Log "- updating file <yellow>#{file}</yellow> with version: <b>#{value}</b>"
    data = fs.readFileSync(file, 'utf8')
    # match all target in packages
    for key, build of builds
      data = updateVersion(data, value, build)
    fs.writeFileSync(file, data)

updateVersion = (data, value, build) ->
  ext     = path.extname(pkg.target)
  bname   = path.basename(pkg.target, ext)
  match   = new RegExp("=(\"|')(.*/?)#{bname}[^\"']?#{ext}(\"|')")
  replace = "=$1$2#{bname}.#{value}#{ext}$3"
  # perform replace
  if data.match(match)
    Log "> found target: #{pkg.target}"
    data.replace(match, replace)
  else
    data

# TODO: somehow need to register to parent job a regex for route matching??
trimVersion = (url) ->
  url.replace(/^([^.]+).*(\.css|\.js)$/i, "$1$2")

# handle versioning based on package.json version (default)

types =
  package: ->
    JSON.parse(fs.readFileSync('./package.json', 'utf8')).version

task = ->
  # initialize version type
  @type or= 'package'
  unless types[@type]
    Log.errorAndExit "Invalid version type #{@type} for job #{@job.name}"

  return (next) ->
    results = updateFiles(@src, @job.app.tasks.build, types[@type]())
    next(null, results)

# TODO: other types that could be made
# 1) based on git commits/tags
# 2) backed on jenkinds builds or env values
# 3) Allow build/version to happen with one command (deploy)

module.exports = task
