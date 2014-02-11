fs      = require('fs')
path    = require('path')
log     = require('../log')
utils   = require('../utils')
events  = require('../events')
async   = require('async')

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
      
# ------- Exports

module.exports.run = run
module.exports.phantom = phantom




# attempt to load the phantom module, which is an optional
# dependency. If not available return an empty object
try
  phantom = require 'phantom'
catch err
  phantom = undefined

# ------- Test Result Formatters

# TODO: need to make this work with mocha at some point

reporters =

  errorsOnly: (el, level, strong) ->
    indent = (level) ->
      ret = ''
      ret = ret + '  ' for i in [0..level]
      ret

    desc = (el) -> $(el).find('> a.description')[0].text
    tick = (el) -> if $(el).is('.passed') then '✓ ' else '✖ '

    if typeof el is 'number'
      return "Passed: " + el + ", Failed: " + level
    else if (!$(el).is(".passed"))
      return indent(level) + tick(el) + desc(el)

  silent: -> return ""

  passOrFail: (el, level, strong) ->
    if typeof el is 'number'
      return "Passed: " + el + ", Failed: " + level

  formatColors: (el, level, strong) ->
    indent = (level) ->
      ret = ''
      ret = ret + '  ' for i in [0..level]
      ret

    tick = (el) ->
      if $(el).is('.passed') then '\x1B[32m✓\x1B[0m' else '\x1B[31m✖'

    desc = (el, strong = false) ->
      ret = $(el).find('> a.description')
      ret = strong and '\x1B[1m' + ret[0].text or ret[0].text

    # display final results
    if typeof el is 'number'
      results= "-------------------------------------\n"
      results += "\x1B[32m✓\x1B[0m\x1B[1m Passed: \x1B[0m" + el
      if level > 0
        results += "\n\x1B[31m✖ \x1B[0m\x1B[1mFailed: \x1B[0m" + level
      return results
    # format output
    else
      return '\x1B[1m' + indent(level) + tick(el) + ' ' + desc(el, strong)

# ------- Wait for certain page elements to become visible

waitFor = (->

  getTime = -> (new Date).getTime()

  return (test, doIt, duration) ->
    duration or= 6000
    start = getTime()
    finish = start + duration
    int = undefined

    # looop function to call using setInterval
    looop = ->
      time = getTime()
      timeout = (time >= finish)

      # callback for page evaluate that receives results
      testCallback = (condition) ->
        # No more time or condition fulfilled
        if condition
          clearInterval(int)
          doIt(time - start)
        # THEN, no moretime but condition unfulfilled
        if timeout and not condition
          clearInterval(int)
          doIt(0, "Timeout for page condition.")

      # perform the test evaluation
      test(testCallback)

    # the intervale number
    int = setInterval(looop, 1000 )
)()

# ------- Jasmine Functions

jasmine_parseTestResults = (report) ->
  # parameters need to be passed in as a simple string so we
  # need to turn report back into a real javascript function
  eval("report = " + report)

  # TODO: at some point, do we need to inject jQuery?

  # handle looping over suites
  printSuites = (root, level) ->
    level or= 0
    $(root).find('div.suite').each( (i, el) ->
      output = report(el, level, true)
      if $(el).parents('div.suite').length is level
        window.callPhantom(output) if output
        printSpecs(el, level + 1)
      printSuites(el, level + 1)
    )

  # handle looping over specs
  printSpecs = (root, level) ->
    level or= 0
    $(root).find('> .specSummary').each( (i, el) ->
      output = report(el, level)
      window.callPhantom(output) if output
    )

  # our starting point
  printSuites($('div.jasmine_reporter'))

  # handle results
  failed = document.body.querySelectorAll('div.jasmine_reporter div.specSummary.failed').length
  passed = document.body.querySelectorAll('div.jasmine_reporter div.specSummary.passed').length
  window.callPhantom(report(passed, failed))

  # return results, these will be eventually passed to the
  # the callback function that was provided initially.
  return passed: passed, failed: failed

jasmine_checkTestResults = (page) ->
  (checkComplete) ->
    isCheckComplete = -> document.querySelector(".duration")?.innerText
    page.evaluate(isCheckComplete, checkComplete)

# ------- Public Functions

run = (filepath, options, callback, port = 12300) ->
  log.info "Testing file <yellow>#{filepath}</yellow> on port <blue>#{port}</blue>"
  phantom.create( (ph) ->
    ph.createPage( (page) ->

      # print console.log output from the webpage
      page.set('onConsoleMessage', (msg) -> console.log(msg))

      # page callback, kind of a hackish way to only allow our phantom
      # script to make use of console.log so we only see test results.
      page.set('onCallback', (msg) -> console.log(msg) if msg)

      # open the filepath and beging tests
      page.open filepath, (status) ->
        if status isnt "success"
          ph.exit()
          callback({ error: "Cannot open URL" })
          return

        # assign the appropiate framework functions
        checkTestResults = jasmine_checkTestResults(page)
        parseTestResults = jasmine_parseTestResults

        # function to call upon completion of test parsing
        complete = (results) ->
          ph.exit()
          callback?(results)

        # ability to request different type of outputs, default to formatColors
        reporter = reporters[options.output]


        # function to call the parsing function, along with callback once
        # everything is complete and the reporter instance that is passed
        # to the parseTestResults function. If time parameter is 0 then 
        # assume that the tests never fully completed.
        evalTestResults = (time, err) ->
          if err
            complete({error: err})
          else
            page.evaluate( parseTestResults, complete, new String(reporter))

        # wait for indication tests are done and then
        # eval/print the test results, all passing, yay!
        waitFor(checkTestResults, evalTestResults)
    )
  , { port: port } )

# ------- Exports

# check to make sure phantom is loaded correctly and if
# not then display an appropiate error message...
if phantom
  module.exports.run = run
else
  module.exports.run = -> log.error "Unable to require('phantom') npm module..."

# export reporters object to allow custom code
module.exports = -> return (next) ->
