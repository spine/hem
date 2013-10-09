phantom = require 'phantom'

# formatters to display test results

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
    else
      if (!$(el).is(".passed"))
        return indent(level) + tick(el) + desc(el)
      else
        return null

  passOrFail: (el, level, strong) ->
    if typeof el is 'number'
      return "Passed: " + el + ", Failed: " + level

  formatColors: (el, level, strong) ->
    indent = (level) ->
      ret = ''
      for i in [0..level]
        ret = ret + '  '
      return ret

    tick = (el) ->
      if $(el).is('.passed') then '\x1B[32m✓\x1B[0m' else '\x1B[31m✖'

    desc = (el, strong) ->
      strong or= false
      ret = $(el).find('> a.description')
      ret = strong and '\x1B[1m' + ret[0].text or ret[0].text

    if typeof el is 'number'
      results= "-------------------------------------\n"
      results += "\x1B[32m✓\x1B[0m\x1B[1m Passed: \x1B[0m" + el
      if level > 0
        results += "\n\x1B[31m✖ \x1B[0m\x1B[1mFailed: \x1B[0m" + level
      return results
    else
      return '\x1B[1m' + indent(level) + tick(el) + ' ' + desc(el, strong)

# wait for method used in page evaluation
waitFor = (->

  getTime = -> (new Date).getTime()

  return (test, doIt, duration) ->
    duration or= 10000
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
          console.log("ERROR - Timeout for page condition.")
          clearInterval(int)
          ph.exit()

      # perform the test evaluation
      test(testCallback)

    # the intervale number
    int = setInterval(looop, 1000 )
)()


module.exports = (filepath, reportStyle = "formatColors") ->
  phantom.create (ph) ->
    ph.createPage (page) ->

      # print console.log output from the webpage
      page.set('onConsoleMessage', (msg) -> console.log(msg))

      # page callback, kind of a hackish way to only allow our phantom
      # script to make use of console.log so we only see test results.
      page.set('onCallback', (msg) -> console.log(msg) if msg)

      # open the filepath and beging tests
      page.open filepath, (status) ->
        if status isnt "success"
          console.log("Cannot open URL")
          ph.exit()

        check = (callback) ->
          isTestComplete = -> document.querySelector(".duration")?.innerText
          page.evaluate(isTestComplete, callback)

        parseTestResults = (report) ->
          # parameters need to be passed in as a simple string so we
          # need to turn report back into a real javascript function
          eval("report = " + report)

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

          # handle fails
          fails  = document.body.querySelectorAll('div.jasmine_reporter div.specSummary.failed')
          passed = document.body.querySelectorAll('div.jasmine_reporter div.specSummary.passed')
          window.callPhantom(report(passed.length, fails.length))

        # ability to request different type of outputs, default to formatColors
        reporter = reporters[reportStyle or "formatColors"]

        # function to call the parsing function, along with callback once
        # everything is complete and the reporter instance that is passed
        # to the parseTestResults function
        evalTests = (time) ->
          page.evaluate( parseTestResults, (-> ph.exit()), new String(reporter))

        # wait for indication tests are done and then
        # eval/print the test results, all passing, yay!
        waitFor(check, evalTests)

