Dependency = require('../dependency')
Stitch     = require('../stitch')
Log        = require('../log')
utils      = require('../utils')
path       = require('path')
uglifyjs   = require('uglify-js')

# ---------- helper function to perform compiles

compile = (task) ->
    result = [compileModules(task)].join("\n")
    result = uglifyjs.minify(result, {fromString: true}).code if task.argv().compress
    result

compileModules = (task) ->
  # create stitch/dependency modules only on first call
  task.stitch or= new Stitch(task.src)
  task.depend or= new Dependency(task.modules)
  # perform compilation
  modules = task.depend.resolve().concat(task.stitch.resolve())
  if modules and task.bundle
    Stitch.bundle(task.bundle, modules)
  else
    ""

compileLibs = (task) ->
  task.stitchLibs or= new Stitch(task.lib)
  task.stitchLibs.join()

# ---------- define task

task = ->
  # for now forcing use of commonjs bundler
  @targetExt = "js"
  @bundle    = "require"

  # javascript to add before/after the stitch file
  @before = utils.arrayToString(@before or "") if @before
  @after  = utils.arrayToString(@after or "")  if @after

  return (params) ->
    # remove the file module from Stitch so its recompiled
    @stitch?.clear(params.watch) if params.watch

    # extra logging for debug mode
    extra = (@argv().compress and " <b>--using compression</b>") or ""
    Log.info "- Building target: <yellow@target}</yellow>#{extra}"

    # compile source
    try
      source = compile(@)
    catch ex
      @handleError(ex)
      return ""

    # determine if we need to write to filesystem
    @write(source)

module.exports = task
