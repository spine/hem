fs    = require('fs')
utils = require('./utils')

# ------- Public Functions 

    # TODO: only ONE app at a time!!!

run = (apps, options = {}) ->
    # TODO: is karam avaliable, use that,
    # - fall back to phantomjs
    # - otherwise just open file in browser??

    runKarma(apps, options)

# ------- Test Functions 

runPhantomjs = (apps, options = {}) ->
  # look at https://github.com/sgentle/phantomjs-node
  # could spin up phantomjs and evaulate rendered page?

runKarma = (apps, options = {}) ->
  # use custom testacular config file provided by user
  testConfig = fs.existsSync(options.config) and fs.realpathSync(options.config)

  # create config file to pass into server if user doesn't supply a file to use
  testConfig or=
    singleRun  : options.singleRun or true
    basePath   : options.basePath
    reporters  : ['progress']
    logLevel   : 'info'
    frameworks : ['jasmine']
    browsers   : options.browser and options.browser.split(/[ ,]+/) or ['PhantomJS']
    files      : createKarmaFileList(apps)
  
  # start testacular server
  require('karma').server.start(testConfig)

createKarmaFileList = (apps) ->
  for app in apps
    return [app.test.target, app.js.target]
    # TODO: need to add special js to load the specs in... should be a part of the jasmine type during builds, either that
    # or don't use stitch on jasmine files, just concat..

# ------- Exports

module.exports.run = run


