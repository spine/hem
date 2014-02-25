Stitch = require('../stitch')

# ---------- define task

task = ->

  # return css task
  return (next, params) ->
    # handle calls from watch
    Stitch.remove(params.watch) if params.watch

    # stitch everything together...
    @stitch or= new Stitch(@src, "css")
    results   = @stitch.resolve()

    # finish task
    next(null, results)

module.exports = task
