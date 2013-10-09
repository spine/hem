fs    = require('fs')
utils = require('./utils')

# ------- Public Functions 

run = (apps, options = {}) ->
    # TODO: is karam avaliable, use that, copy code from compilers
    # - fall back to phantomjs
    # - otherwise just open file in browser??

    # probably need to loop over apps and run karma for each??
    runKarma(app, options) for app in apps

# ------- Test Functions 

runPhantomjs = (app, options = {}) ->
  # look at https://github.com/sgentle/phantomjs-node
  # could spin up phantomjs and evaulate rendered page?

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


