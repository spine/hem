Stitch = require('../stitch')

# ---------- define task

task = ->
  @targetExt = "css"
  @bundle  or= true

  # return css task
  return (next, params) ->
    # handle calls from watch
    Stitch.remove(params.watch) if params.watch

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

module.exports = task
