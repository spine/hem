uglifycss = require('uglifycss')
Stitch    = require('../stitch')

# ---------- define task

task = ->
  @targetExt = "css"
  @bundle    = true
  @stitch  or= new Stitch(@src, "css")

  # main task to compile and minify css
  return (params) ->
    # remove the file module from Stitch so its recompiled
    Stitch.remove(params.watch) if params.watch

    try
      # join and minify
      source = @stitch.resolve( bundle: @bundle )
      source = uglifycss.processString(source) if @argv().compress
    catch ex
      @handleError(ex)
      return ""

    # determine if we need to write to filesystem
    @write(source)

module.exports = task
