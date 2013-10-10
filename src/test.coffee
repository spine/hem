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
        runTests = runPhantom
      when "karma"
        runTests = runKarma
      else
        # TODO: open test file in browser as default??
        throw new Error("Invalid or unset test runner value: #{options.runner}")

    # need to loop over apps and run tests for each target app
    for app in apps
      runTests(app, options)

# ------- Test Functions

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
    process.exit(results.fails)
  )

runKarma = (app, options = {}) ->
  # use custom testacular config file provided by user
  testConfig = fs.existsSync(options.config) and fs.realpathSync(options.config)

  # create config file to pass into server if user doesn't supply a file to use
  testConfig or=
    singleRun  : options.singleRun or true
    basePath   : options.basePath
    reporters  : ['progress']
    logLevel   : 'info'
    frameworks : [options.framework]
    browsers   : options.browser and options.browser.split(/[ ,]+/) or ['PhantomJS']
    files      : createKarmaFileList(app)

  # start testacular server
  require('karma').server.start(testConfig)

createKarmaFileList = (app) ->
  # get the test package and return the appropiate file list

# ------- Exports

module.exports.run = run


