Log = require('../log')
fs  = require('fs')

# ---------- define task

task = ->
  @jobsToClean or= ['build', 'deploy']

  return (next) ->
    # find build/deploy jobs
    tasksToClean = []

    # get list of tasks
    for jobname, job of @job.app.jobs when jobname in @jobsToClean
      tasksToClean = tasksToClean.concat job.tasks
    
    # loop over the tasks in the job and remove the target
    for task in tasksToClean
      if task.target and fs.existsSync(task.target)
        Log.info "- removing <yellow>#{task.target}</yellow>"

    # task is finished
    next()

module.exports = task
