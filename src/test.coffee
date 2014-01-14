fs      = require('fs')
path    = require('path')
async   = require('async')
log     = require('./log')
utils   = require('./utils')
events  = require('./events')
phantom = require('./phantom')

# ------- Public Functions

run = (apps, options) ->
  # determine runner
  switch options.runner
    when "phantom"
      runTests = if phantom.run then runPhantom else runBrowser
    when "browser"
      runTests = runBrowser
    else
      log.errorAndExit("Invalid or unset test runner value: <yellow>#{options.runner}</yellow>")

  # loop over apps and run tests for each target app
  runTests(apps, options)

# ------- Test Functions

runBrowser = (apps, options, done) ->
  open  = require("open")
  tasks = {}

  # loop over target apps
  for app in apps
    testName = app.name
    # TODO: need to make sure test files exist, place in getTestTask() call!!
    testFile = app.getTestPackage().getTestIndexFile()
    tasks[testName] = do(testFile) ->
      (done) ->
        open(testFile)
        done()

  # if single run then just add to async series
  if options.singleRun
    async.series(tasks)
  else
    q = async.queue( ((task, callback) -> task(callback)), 1)
    for task, taskObject of tasks
      events.on("watch", (app, pkg, file) -> q.push(tasks[app.name]))

runPhantom = (apps, options, done) ->
  # set some other defaults
  options.output or= "passOrFail"
  tasks = {}

  # loop over apps to create test runner functions
  for app in apps
    testName = app.name
    # TODO: need to make sure test files exist, place in getTestTask() call!!
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
    for task, taskObject of tasks
      # setup watch and use q.push(taskObject) to assign to q
      events.on("watch", (app, pkg, file) ->
        q.push(tasks[app.name])
      )

# TODO: not sure how to incorperate all this...

  constructor: (task)  ->

    # get test home directory based on target file location
    @testHome  = path.dirname(@target)
    @framework = task.test

    # test to make sure framework is set correctly
    if @framework not in ['jasmine','mocha']
      log.errorAndExit("Test frameworks value is not valid: #{@framework}")

    # javascript to run at end of specs file
    @after +=
    """
    // HEM: load in specs from test js file
    var onlyMatchingModules = \"#{_argv.grep or ""}\";
    for (var key in #{@commonjs}.modules) {
      if (onlyMatchingModules && key.indexOf(onlyMatchingModules) == -1) {
        continue;
      }
      #{@commonjs}(key); 
    }
    """

  createTestFiles: ->
    # create test html file
    # TODO: check if file already exists!!
    indexFile = @getTestIndexFile()
    files = []
    files.push.apply(files, @getFrameworkFiles())
    files.push.apply(files, @getAllTestTargets())
    template = utils.tmpl("testing/index", { commonjs: @commonjs, files: files, before: @before } )
    fs.outputFileSync(indexFile, template)

    # copy the framework files if they aren't present
    frameworkPath = path.resolve(__dirname, "../assets/testing/#{@framework}")
    for file in fs.readdirSync(frameworkPath)
      if path.extname(file) in [".js",".css"]
        filepath = path.resolve(@testHome, "#{@framework}/#{file}")
        utils.copyFile(path.resolve(frameworkPath, file), filepath)

  getAllTestTargets: (relative = true) ->
    targets   = []
    homeRoute = path.dirname(@route)

    # create function to determine route/path
    relativeFn = (home, target) ->
      if relative
        path.relative(home, target)
      else
        target

    # first get dependencies
    for dep in @depends
      for depapp in _hem.allApps when depapp.name is dep
        for pkg in depapp.packages
          continue unless pkg.constructor.name is "JsPackage"
          url = relativeFn(homeRoute, pkg.route)
          pth = relativeFn(@testHome, pkg.target) 
          targets.push({ url: url, path: pth })

    # get app targets
    for pkg in @app.packages
      continue unless pkg.constructor.name is "JsPackage"
      url = relativeFn(homeRoute, pkg.route)
      pth = relativeFn(@testHome, pkg.target)
      targets.push({ url: url, path: pth })

    # finally add main test target file
    url = relativeFn(homeRoute, pkg.route)
    pth = relativeFn(@testHome, pkg.target)
    targets.push({ url: url, path: pth })
    targets

  getFrameworkFiles: ->
    targets = []
    frameworkPath = path.resolve(__dirname, "../assets/testing/#{@framework}")
    for file in fs.readdirSync(frameworkPath)
      if path.extname(file) in [".js",".css"]
        url = "#{@framework}/#{file}"
        targets.push({ url: url, path: url })
    targets

  getTestIndexFile: ->
    path.resolve(@testHome,'index.html')


# ------- Exports

module.exports.run = run
module.exports.phantom = phantom


