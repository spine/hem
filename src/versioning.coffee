fs    = require('fs')
path  = require('path')
types = {}

# private functions

replaceTargetsInFiles = (files, version, pkgs) ->
  for file in files
    console.log "updating file #{file} with version #{version}"
    data = fs.readFileSync(file, 'utf8')
    # match all target in packages
    for pkg in pkgs
      data = replaceTargetInData(data, version, pkg)
    fs.writeFileSync(file, data)

replaceTargetInData = (data, version, pkg) ->
  ext     = path.extname(pkg.target)
  name    = path.basename(pkg.target, ext)
  match   = new RegExp("=(\"|')#{name}[^\"']?#{ext}(\"|')")
  replace = "=$1#{name}.#{version}#{ext}$2"
  data.replace(match, replace)

# handle versioning based on package.json version (default)

types.package =

  getVersion: ->
    JSON.parse(fs.readFileSync('./package.json', 'utf8')).version

  updateFiles: (files, pkgs) ->
    replaceTargetsInFiles(files, @getVersion(), pkgs)

  trimVersion: (url) ->
    url.replace(/^([^.]+).*(\.css|\.js)$/i, "$1$2")

# TODO: other types that could be made
# 1) based on git commits/tags
# 2) backed on jenkinds builds
# 3) Allow build/version to happen with one command
# 4) allow command line options to version command

module.exports = types
