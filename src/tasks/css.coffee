uglifycss = require('uglifycss')
Stitch    = require('../stitch')

# ---------- define task

task = ->
  @targetExt = "css"
  @bundle    = true

  # main task to compile and minify css
  return (params) ->
    @stitch or= new Stitch(@src, "css")

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
