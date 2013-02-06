require('lib/setup')

start = ->
  console.log("starting index");
  return "this is the index"
  
module.exports =
  start: start
    