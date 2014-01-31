Log = require('../log')
fs  = require('fs')

# ---------- define task

task = ->
  @jobsToClean = ['build', 'deploy']

  return (params) ->
    # find build/deploy jobs
    tasksToClean = []

    # get list of tasks
    for job in @job.app.jobs when job in @jobsToClean
      tasksToClean.concat job.tasks

    # loop over the tasks in the job and remove the target
    for task in tasksToClean
      if fs.existsSync(task.target)
        Log.info "- removing <yellow>#{task.target}</yellow>"
        fs.unlinkSync(task.target)

module.exports = task
