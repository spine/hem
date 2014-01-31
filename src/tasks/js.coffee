Dependency = require('../dependency')
Stitch     = require('../stitch')
Log        = require('../log')
utils      = require('../utils')
path       = require('path')
uglifyjs   = require('uglify-js')

# ---------- helper function to perform compiles

compile = (task) ->
  try
    result = [task.before, compileLibs(task.libs), compileModules(task), task.after].join("\n")
    result = uglifyjs.minify(result, {fromString: true}).code if task.job.argv.compress
    result
  catch ex
    task.handleError(ex)
    return ""

compileModules = (task) ->
  task.stitch or= new Stitch(task.src)
  task.depend or= new Dependency(task.modules)
  _modules  = task.depend.resolve().concat(task.stitch.resolve())
  if _modules
    Stitch.template(task.commonjs, _modules)
  else
    ""

compileLibs = (files, parentDir = "") ->

  # TODO: need to perform similar operation as stitch in that only
  # compilable code is used... refactor Stitch class to handle this?? except
  # we don't want the code actually stitched in a template, just plain old js

  # check if folder or file
  results = []
  for file in files
    slash = if parentDir is "" then "" else path.sep
    file  = parentDir + slash + file
    if fs.existsSync(file)
      stats = fs.lstatSync(file)
      if (stats.isDirectory())
        dir = fs.readdirSync(file)
        results.push compileLibs(task, dir, file)
      else if stats.isFile() and path.extname(file) in ['.js','.coffee']
        results.push fs.readFileSync(file, 'utf8')
  results.join("\n")

# ---------- define task

task = ->
  # for now forcing use of commonjs bundler
  @targetExt  = "js"
  @bundle     = true
  @commonjs or= 'required'

  # javascript to add before/after the stitch file
  @before   = utils.arrayToString(@before or "")
  @after    = utils.arrayToString(@after or "")

  # dependecy on other apps?
  @depends  = utils.toArray(@depends)

  return (params) ->
    # remove the files module from Stitch so its recompiled
    Stitch.clear(params.watch) if params.watch

    # extra logging for debug mode
    extra = (@job.argv.compress and " <b>--using compression</b>") or ""
    Log.info "- Building target: <yellow@target}</yellow>#{extra}"

    # compile source
    source = compile(@)

    # determine if we need to write to filesystem
    write = @job.argv.command isnt "server"
    if source and write
      dirname = path.dirname(task.target)
      fs.mkdirsSync(dirname) unless fs.existsSync(dirname)
      fs.writeFileSync(task.target, source)
    source

module.exports = task
