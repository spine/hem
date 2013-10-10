fs    = require('fs')
path  = require('path')
utils = require('./utils')
log   = require('./log')
types = {}

# private functions

updateVersionInAppFiles = (files, packages, value) ->
  for file in files
    log "- updating file <yellow>#{file}</yellow> with version: <b>#{value}</b>"
    data = fs.readFileSync(file, 'utf8')
    # match all target in packages
    for key, pkg of packages
      data = updateVersionInData(data, value, pkg)
    fs.writeFileSync(file, data)

updateVersionInData = (data, value, pkg) ->
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

types.package = class NpmPackageVersion

  constructor: (app, options = {}) ->
    @app   = app
    @files = utils.toArray(options.files).map (file) =>
      @app.applyRootDir(file)[0]

  getVersion: ->
    JSON.parse(fs.readFileSync('./package.json', 'utf8')).version

  update: () ->
    updateVersionInAppFiles(@files, @app.packages, @getVersion())

  trim: (url) ->
    url.replace(/^([^.]+).*(\.css|\.js)$/i, "$1$2")

# TODO: other types that could be made
# 1) based on git commits/tags
# 2) backed on jenkinds builds or env values
# 3) Allow build/version to happen with one command (deploy)

module.exports = types
