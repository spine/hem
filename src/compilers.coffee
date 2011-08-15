fs        = require('fs')
compilers = {}

compilers.js = (path) ->
  fs.readFileSync path, 'utf8'
    
try
  cs = require 'coffee-script'
  compilers.coffee = (path) ->
    cs.compile(fs.readFileSync(path, 'utf8'), filename: path)
catch err

eco = require 'eco'
compilers.eco = (path) ->
  eco.precompile fs.readFileSync path, 'utf8'

compilers.tmpl = (path) ->
  content = fs.readFileSync(path, 'utf8')
  "var template = jQuery.template(#{JSON.stringify(content)});\n" +
  "module.exports = (function(data){ return jQuery.tmpl(template, data); });\n"

require.extensions['.tmpl'] = (module, filename) -> 
  module._compile(compilers.tmpl(filename))
  
module.exports = compilers