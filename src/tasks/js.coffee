Stitch     = require('../stitch')
Log        = require('../log')
utils      = require('../utils')

# ---------- helper function to perform compiles

compile = (task) ->
  results = []

  # compile different src folders/paths
  mods = compileMods(task, task.src)
  libs = compileLibs(task, task.lib)
  mods = [mods] unless Array.isArray(mods)
  libs = [libs] unless Array.isArray(libs)
  results.push.apply results, mods
  results.push.apply results, libs

  # deal with setting targets
  if task.bundle
    source = []
    for result in results
      source.push result.source
    result =
      source : source.join("\n")
      target : task.target
      route  : task.route
  else
    for result in results
      result.target = "??"
      result.route  = "??"
    results

compileMods = (task, src) ->
  # create stitch/dependency modules only on first call
  task.stitchMods or= new Stitch(src)
  task.stitchMods.resolve
    bundle   : task.bundle
    commonjs : task.commonjs
    npm      : task.npm

compileLibs = (task, lib) ->
  # libs are always bundled as a simple join
  task.stitchLibs or= new Stitch(lib)
  task.stitchLibs.resolve
    bundle   : true
    commonjs : false

# ---------- define task

task = ->
  # for now forcing use of commonjs bundler
  @targetExt = "js"
  @bundle    or= true
  @commonjs  or= "require"
  @npm       or= false

  # javascript to add before/after the stitch file
  @before = utils.arrayToString(@before or "") if @before
  @after  = utils.arrayToString(@after  or "") if @after

  # main task to compile css
  return (next) ->
    # extra logging for debug mode
    extra = (@argv().compress and " <b>--using compression</b>") or ""
    Log.info "- Building target: <yellow>#{@target}</yellow>#{extra}"

    # compile source
    try
      next(null, compile(@))
    catch ex
      next(ex)

module.exports = task
