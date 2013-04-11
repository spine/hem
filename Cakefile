{print} = require 'util'
{spawn} = require 'child_process'

build = (callback, watch = false) ->
  coffee = spawn 'coffee', [(if watch then '-cw' else '-c'), '-o', 'lib', 'src']
  coffee.stderr.on 'data', (data) ->
    process.stderr.write data.toString()
  coffee.stdout.on 'data', (data) ->
    print data.toString()
  coffee.on 'exit', (code) ->
    callback?() if code is 0

task 'build', 'Build lib/ from src/', ->
  build()

task 'watch', 'Watch lib/ from src/', ->
  build(null, true)
