fs    = require('fs')
path  = require('path')
utils = require('../utils')
log   = require('../log')

# private functions

updateVersionInAppFiles = (files, builds, value) ->
  # TODO: use node-glob!!
  for file in files
    log "- updating file <yellow>#{file}</yellow> with version: <b>#{value}</b>"
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
    log "> found target: #{pkg.target}"
    data.replace(match, replace)
  else
    data

# handle versioning based on package.json version (default)

npmpackage = (task, params = {}) ->
  getVersion = ->
    JSON.parse(fs.readFileSync('./package.json', 'utf8')).version

  update = ->
    updateVersionInAppFiles(task.src, task.app.tasks.build, getVersion())

  trim = (url) ->
    url.replace(/^([^.]+).*(\.css|\.js)$/i, "$1$2")

  if params.trim
    trim(cmd.path)
  else
    update()

# TODO: other types that could be made
# 1) based on git commits/tags
# 2) backed on jenkinds builds or env values
# 3) Allow build/version to happen with one command (deploy)

module.exports = npmpackage
