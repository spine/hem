fs = require('fs')

# ------- Public Functions 

start = (hem, hemapps, options = {}) ->
    # TODO: is karam avaliable, use that,
    # - fall back to phantomjs
    # - otherwise just open file in browser??

    startKarma(hem, hemapps, options)

# ------- Test Functions 

startKarma = (hemapps, options = {}) ->
  # use custom testacular config file provided by user
  testConfig = fs.existsSync(options.config) and fs.realpathSync(options.config)

  # create config file to pass into server if user doesn't supply a file to use
  testConfig or=
    configFile : require.resolve("../assets/testacular.conf.js")
    singleRun  : options.singleRun or true
    basePath   : hem.homeDir
    logLevel   : 'error'
    browsers   : options.browser and options.browser.split(/[ ,]+/) or ['PhantomJS']
    files      : createKarmaFileList(hemapps)

  # start testacular server
  require('karma').server.start(testConfig)

createKarmaFileList = (hemapps) ->
  # TODO: other adapters?
  # look at at test type to see what assets we add
  fileList = [require.resolve("../node_modules/karma/adapter/lib/jasmine.js"),
              require.resolve("../node_modules/karma/adapter/jasmine.js")]

  # loop over javascript hem applications and add their test targets
  fileList.push app.test.target for app in hemapps
  return fileList

# ------- Exports

module.exports.start = start


