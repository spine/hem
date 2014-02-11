Stitch = require('../stitch')

# ---------- define task

task = ->
  @targetExt = "css"
  @bundle    = true

  # main task to compile css
  return (next) ->
    try
      @stitch or= new Stitch(@src, "css")
      results   = @stitch.resolve( bundle: @bundle )
      # determine targets
      if Array.isArray(results)
        for result in results
          result.target = "???"
          result.route  = "???"
      else
        results.target = @target
        results.route  = @route
      # finish task
      next(null, results)
    catch ex
      next(ex)

module.exports = task
