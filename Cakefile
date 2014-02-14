{print}       = require 'sys'
{spawn, exec} = require 'child_process'

option '', '--grep [string]', 'only run tests matching <pattern>'

build = (watch, callback) ->
  if typeof watch is 'function'
    callback = watch
    watch = false
  options = ['-c', '-o', 'lib', 'src']
  options.unshift '-w' if watch

  coffee = spawn 'coffee', options
  coffee.stdout.on 'data', (data) -> print data.toString()
  coffee.stderr.on 'data', (data) -> print data.toString()
  coffee.on 'exit', (status) -> callback?() if status is 0

test = (options, callback) ->
  args  = "--compilers coffee:coffee-script/register "
  args += "-r should "
  args += "-R spec "
  args += "--slow 5000 "
  args += "--timeout 40000 "
  args += ('--grep ' + options.grep) if options.grep
  exec "node_modules/mocha/bin/mocha #{args}",
    (err, stdout, stderr) ->
      print stdout if stdout?
      print stderr if stderr?

task 'build', 'Build from /src folder', ->
  build()

task 'watch', 'Watch from /src folder', ->
  build true

task 'test', 'Run Tests', (options) ->
  test(options)
