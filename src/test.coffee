fs      = require('fs')
path    = require('path')
log     = require('./log')
utils   = require('./utils')
events  = require('./events')
phantom = require('./phantom')
async   = require('async')

# ------- Public Functions

run = (apps, options) ->
  # determine runner
  switch options.runner
    when "phantom"
      runTests = if phantom.run then runPhantom else runBrowser
    when "karma"
      runTests = runKarma
    when "browser"
      runTests = runBrowser
    else
      log.errorAndExit("Invalid or unset test runner value: <yellow>#{options.runner}</yellow>")

  # loop over apps and run tests for each target app
  runTests(apps, options)

  # TODO: thoughts...
  # 3) need some way to set pre/post test javascript into specs file for both phantom/karma
  # 4) pass in argument to only require certain specs to run!! goes with #3
  # 5) use karma server once, and karma run after that, use our own watch to trigger run or
  #    run tests from multiple projects

# ------- Test Functions

runBrowser = (apps, options, done) ->
  open  = require("open")
  tasks = {}

  # loop over target apps
  for app in apps
    testName = app.name
    testFile = app.getTestPackage().getTestIndexFile()
    tasks[testName] = do(testFile) ->
      (done) ->
        open(testFile)
        done()

  # if single run then just add to async series
  if options.singleRun
    async.series(tasks)
  else
    # TODO: watch should refresh the current tabl, not re-open
    q = async.queue( ((task, callback) -> task(callback)), 1)
    events.on("watch", (app, pkg, file) -> q.push(tasks[app.name]))

runPhantom = (apps, options, done) ->
  # set some other defaults
  options.output or= "passOrFail"
  tasks = {}

  # loop over apps to create test runner functions
  for app in apps
    testName = app.name
    # TODO: perform injection with phantomjs instead!
    testFile = app.getTestPackage().getTestIndexFile()
    testPort = 12300 + Object.keys(tasks).length

    # add phantom call to tasks array
    tasks[testName] = do(testName, testFile, testPort) ->
      (done) ->
        log("Testing application targets: <green>#{testName}</green>")
        phantom.run(testFile, options, (results) ->
          log.error results.error if results.error
          done(null, results)
        , testPort)

  # if single run then just add to async series
  if options.singleRun
    async.series(tasks, (err, results) ->
      exitCode = 0
      for name, result of results
        exitCode += result.failed and result.failed or 0
        exitCode += result.error and 1 or 0
      process.exit(exitCode)
    )
  # else add to queue and setup watch
  else
    q = async.queue( ((task, callback) -> task(callback)), 1)
    events.on("watch", (app, pkg, file) -> 
      q.push(tasks[app.name]) 
    )

runKarma = (apps, options = {}) ->
  # TODO: require karma from project folder instead!
  karma = require('karma').server
  tasks = {}

  for app in apps

    # create config file to pass into server if user doesn't supply a file to use
    testConfig =
      singleRun  : true
      basePath   : options.basePath
      reporters  : [options.reporters or 'progress']
      logLevel   : options.logLevel or 'error'
      frameworks : [options.frameworks or 'jasmine']
      browsers   : options.browser and options.browser.split(/[ ,]+/) or ['PhantomJS']
      files      : createKarmaFileList(app)
      autoWatch  : false

    # handle junit special case for report file location
    if 'junit' in testConfig.reporters
      testConfig.junitReporter =
        outputFile: app.name + '-test-results.xml'
        suite: app.name

    # create task
    tasks[app.name] = do(app, testConfig) ->
      (done) ->
        log("Testing application targets: <green>#{app.name}</green>")
        # karma callback
        callback = (exitCode) ->
          # async.series calleback
          done(null, { failed: exitCode } )
        # start testacular server
        karma.start(testConfig, callback)

  # if single run then just add to async series
  if options.singleRun
    async.series(tasks, (err, results) ->
      exitCode = 0
      for name, result of results
        exitCode += result.failed and result.failed or 0
        exitCode += result.error and 1 or 0
      process.exit(exitCode)
    )
  # else add to queue and setup watch
  else
    q = async.queue( ((task, callback) -> task(callback)), 1)
    events.on("watch", (app, pkg, file) -> q.push(tasks[app.name]) )


createKarmaFileList = (app) ->
  files = []
  for target in app.getTestPackage().getAllTestTargets(false)
    files.push(target.path)
  files

# ------- Exports

module.exports.run = run
module.exports.phantom = phantom


