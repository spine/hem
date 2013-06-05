fs = require('fs')

# ------- Public Functions 

start = (packages, options = {}) ->
    # TODO: determine whether to use phantomjs or karma for testing
    startKarma(packages, singleRun)

# ------- Test Functions 

startKarma = (packages, options = {}) ->
  # use custom testacular config file provided by user
  testConfig = fs.existsSync(options.config) and fs.realpathSync(options.config)

  # create config file to pass into server if user doesn't supply a file to use
  testConfig or=
    configFile : require.resolve("../assets/testacular.conf.js")
    singleRun  : options.singleRun or true
    basePath   : process.cwd()
    logLevel   : 'error'
    browsers   : options.browser and options.browser.split(/[ ,]+/) or ['PhantomJS']
    files      : createKarmaFileList(packages)

  # start testacular server
  require('karma').server.start(testConfig)

createKarmaFileList = (packages) ->
  # TODO how to configure this to use other adapters?

  # look at at test type to see what assets we add
  fileList = [require.resolve("../node_modules/karma/adapter/lib/jasmine.js"),
              require.resolve("../node_modules/karma/adapter/jasmine.js")]
  # loop over javascript packages and add their targets
  fileList.push pkg.target for pkg in packages
  return fileList

# ------- Exports

module.exports.start = start


