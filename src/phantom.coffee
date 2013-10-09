phantom = require 'phantom'


module.exports = (filepath) ->
  phantom.create (ph) ->

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
          # method to process evaluation results
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

    ph.createPage (page) ->

      _page = page

      # print console.log output from the webpage
      _page.set('onConsoleMessage', (msg) -> console.log(msg))

      # page callback, kind of a hackish way to only allow our phantom
      # script to make use of console.log so we only see test results.
      _page.set('onCallback', (msg) -> console.log(msg) if msg)

      # open the filepath and beging tests
      _page.open filepath, (status) ->
        if status isnt "success"
          console.log("Cannot open URL")
          ph.exit()

        check = (callback) ->
          _page.evaluate(
            -> document.querySelector(".duration")?.innerText
          ,
            callback
          )

        evalTests = (time) ->
          _page.evaluate( (formatter) ->

            formatColors = (->
              indent = (level) ->
                ret = ''
                for i in [0..level] 
                  ret = ret + '  '
                return ret

              tick = (el) ->
                return if $(el).is('.passed') then '\x1B[32m✓\x1B[0m' else '\x1B[31m✖'

              desc = (el, strong) ->
                strong or= false
                ret = $(el).find('> a.description')
                ret = strong and '\x1B[1m' + ret[0].text or ret[0].text

              return (el, level, strong) ->
                if typeof el is 'number'
                  results= "-------------------------------------\n"
                  results += "\x1B[32m✓\x1B[0m\x1B[1m Passed: \x1B[0m" + el
                  if level > 0
                    results += "\n\x1B[31m✖ \x1B[0m\x1B[1mFailed: \x1B[0m" + level
                  return results
                else
                  return '\x1B[1m' + indent(level) + tick(el) + ' ' + desc(el, strong)
            )()

            errorsOnly = (->
              indent = (level) ->
                ret = ''
                for i in [0..level]
                  ret = ret + '  '
                return ret

              desc = (el) ->
                $(el).find('> a.description')[0].text

              tick = (el) -> $(el).is('.passed') ? '✓ ' : '✖ '

              return (el, level, strong) ->
                if typeof el is 'number'
                  return "Passed: " + el + ", Failed: " + level
                else
                  if (!$(el).is(".passed")) 
                    return indent(level) + tick(el) + desc(el)
                  else
                    return null
            )()

            # ability to request different type of outputs, default to formatColors
            try
              format = eval(formatter or "formatColors")
            catch ex
              format = formatColors

            printSuites = (root, level) ->
              level or= 0
              $(root).find('div.suite').each( (i, el) ->
                output = format(el, level, true)
                if $(el).parents('div.suite').length is level
                  window.callPhantom(output) if output
                  printSpecs(el, level + 1)
                printSuites(el, level + 1)
              )

            printSpecs = (root, level) ->
              level or= 0
              $(root).find('> .specSummary').each( (i, el) ->
                output = format(el, level)
                window.callPhantom(output) if output
              )

            printSuites($('div.jasmine_reporter'))

            # handle fails
            fails  = document.body.querySelectorAll('div.jasmine_reporter div.specSummary.failed')
            passed = document.body.querySelectorAll('div.jasmine_reporter div.specSummary.passed')
            window.callPhantom(format(passed.length, fails.length))
            
          , -> ph.exit() )

        waitFor(check, evalTests)


