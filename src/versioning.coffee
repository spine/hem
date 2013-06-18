fs    = require('fs')
path  = require('path')
utils = require('./utils')
types = {}

# private functions

replaceTargetsInAppFiles = (app, value) ->
  files = utils.toArray(app.versioning.files)
  console.log files
  for file in files
    utils.log "- updating file <yellow>#{file}</yellow> with version: <b>#{value}</b>"
    data = fs.readFileSync(file, 'utf8')
    # match all target in packages
    for pkg in app.packages
      data = replaceTargetInData(data, value, pkg)
    fs.writeFileSync(file, data)

replaceTargetInData = (data, value, pkg) ->
  ext     = path.extname(pkg.target)
  name    = path.basename(pkg.target, ext)
  match   = new RegExp("=(\"|')#{name}[^\"']?#{ext}(\"|')")
  replace = "=$1#{name}.#{value}#{ext}$2"
  data.replace(match, replace)

# handle versioning based on package.json version (default)

types.package =

  getVersion: ->
    JSON.parse(fs.readFileSync('./package.json', 'utf8')).version

  updateVersion: (app) ->
    replaceTargetsInAppFiles(app, @getVersion())

  trimVersion: (url) ->
    url.replace(/^([^.]+).*(\.css|\.js)$/i, "$1$2")

# TODO: other types that could be made
# 1) based on git commits/tags
# 2) backed on jenkinds builds
# 3) Allow build/version to happen with one command
# 4) allow command line options to version command

module.exports = types
