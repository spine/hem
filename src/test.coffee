fs      = require('fs')
path    = require('path')
log     = require('./log')
utils   = require('./utils')
phantom = require('./phantom')

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
      throw new Error("Invalid or unset test runner value: #{options.runner}")

  # need to loop over apps and run tests for each target app
  for app in apps
    runTests(app, options)

  # TODO: thoughts...
  # 1) pass apps to the runTests method and have it loop over apps
  # 2) use async to run in sequnce!
  # 3) need some way to but pre/post test javascript into file for both phantom/karma
  # 4) pass in argument to only require certain specs to run!! goes with #3
  # 5) use karma server once, and karma run after that, use our own watch to trigger run or 
  #    run tests from multiple projects

# ------- Test Functions

runBrowser = (app, options, done) ->
  open = require("open")
  open(app.getTestPackage().getTestIndexFile())

runPhantom = (app, options, done) ->
  log("Testing  application targets: <green>#{app.name}</green>")
  testFile = app.getTestPackage().getTestIndexFile()

  # set some other defaults
  options.output or= "passOrFail"

  # TODO: need a way for watch to work?, we can use our new event system :o)
  # TODO: need a way to run tests in sequential steps... async library??

  # run phantom
  phantom.run(testFile, options, (results) ->
    # exit with the number of failed tests
    process.exit(results.fails) if options.singleRun
  )

runKarma = (app, options = {}) ->
  # use custom testacular config file provided by user
  testConfig = fs.existsSync(options.config) and fs.realpathSync(options.config)

  # create config file to pass into server if user doesn't supply a file to use
  testConfig or=
    singleRun  : options.singleRun or true
    basePath   : options.basePath
    reporters  : [options.output or 'progress']
    logLevel   : 'info'
    frameworks : [options.framework]
    browsers   : options.browser and options.browser.split(/[ ,]+/) or ['PhantomJS']
    files      : createKarmaFileList(app)

  # callback
  callback = (exitCode) -> 
    process.exit(exitCode) if options.singleRun

  # start testacular server
  require('karma').server.start(testConfig, callback)

createKarmaFileList = (app) ->
  # get the test package and return the appropiate file list

# ------- Exports

module.exports.run = run
module.exports.phantom = phantom


