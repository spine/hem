fs        = require('fs')
path      = require('path')
utils     = require('./utils')
compilers = {}
lmCache   = {}

# Load the modules from the project directory (instead of from the hem 
# node_modules). This allows a lot of the different javascript/css pre
# compilers to be installed in the project vs having to be included with
# the hem package.

# setup project path
projectPath = path.resolve process.cwd()

# helper fuction to perform load/caching of modules
requireLocalModule = (localModule) ->
  modulePath  = "#{projectPath}/node_modules/#{localModule}"
  try 
    lmCache[localModule] or= require modulePath
  catch error
    utils.error("Unable to load <green>#{localModule}</green> module. Try to use 'npm install #{localModule}' in your project directory.")
    console.log error if utils.VERBOSE
    process.exit()

##
## Basic javascript/css files 
##

compilers.js = compilers.css = (_path) ->
  fs.readFileSync _path, 'utf8'

require.extensions['.css'] = (module, filename) ->
  source = JSON.stringify(compilers.css(filename))
  module._compile "module.exports = #{source}", filename

##
## HTML files
##

compilers.html = (_path) ->
  content = fs.readFileSync(_path, 'utf8')
  "module.exports = #{JSON.stringify(content)};\n"

require.extensions['.html'] = (module, filename) ->
  module._compile compilers.html(filename), filename

##
## Compile Coffeescript
##

cs = require 'coffee-script'
compilers.coffee    = (_path) -> compileCoffeescript(_path)
compilers.litcoffee = (_path) -> compileCoffeescript(_path, true)
compileCoffeescript = (_path, literate = false) ->
  try
    cs.compile(fs.readFileSync(_path, 'utf8'), filename: _path, literate: literate)
  catch err
    err.message = "Coffeescript Error: " + err.message
    err.path    = "Coffeescript Path:  " + _path
    err.path    = err.path + ":" + (err.location.first_line + 1) if err.location
    throw err

##
## Eco and Jeco Compiler
##

eco = require('eco')
compilers.eco = (_path) ->
  content = eco.precompile fs.readFileSync _path, 'utf8'
  """
  var content = #{content};
  module.exports = content;
  """

compilers.jeco = (_path) -> 
  content = eco.precompile fs.readFileSync _path, 'utf8'
  """
  module.exports = function(values, data){ 
    var $  = jQuery, result = $();
    values = $.makeArray(values);
    data = data || {};
    for(var i=0; i < values.length; i++) {
      var value = $.extend({}, values[i], data, {index: i});
      var elem  = $((#{content})(value));
      elem.data('item', value);
      $.merge(result, elem);
    }
    return result;
  };
  """

# require.extensions['.eco'] in eco package contains the function
require.extensions['.jeco'] = require.extensions['.eco']

##
## Jade Compiler
##

compilers.jade = (_path) ->
  jade    = requireLocalModule('jade')
  content = fs.readFileSync(_path, 'utf8')
  try
    template = jade.compile content,
      filename: _path
      # compileDebug: compilers.DEBUG
      client: true
    source = template.toString()
    "module.exports = #{source};"
  catch ex
    throw new Error("#{ex} in #{_path}")

require.extensions['.jade'] = (module, filename) ->
  module._compile compilers.jade(filename), filename

##
## Stylus Compiler
##

compilers.stylus = (_path) ->
  stylus  = requireLocalModule('stylus')
  content = fs.readFileSync(_path, 'utf8')
  result  = ''
  stylus(content)
    .include(path.dirname(_path))
    .render((err, css) -> 
      throw err if err
      result = css
    )
  result
  
require.extensions['.styl'] = (module, filename) -> 
  source = JSON.stringify(compilers.stylus(filename))
  module._compile "module.exports = #{source}", filename

##
## Less Compiler
##

compilers.less = (_path) ->
  less    = requireLocalModule('less')
  content = fs.readFileSync(_path, 'utf8')
  result  = ''
  less.render content, (err, css) ->
    throw err if err
    result = css
  result

require.extensions['.less'] = (module, filename) -> 
  source = JSON.stringify(compilers.less(filename))
  module._compile "module.exports = #{source}", filename

##
## Environment Compiler
## 

# This creates a javascript module based off key values found in environment
# variables or in the package.json file. Usefule for inserting build info
# that would come frome a CI server (like jenkins)

compilers.env = (_path) ->
  content  = fs.readFileSync(_path, 'utf8')
  envhash  = JSON.parse(content)
  packjson = JSON.parse(fs.readFileSync(path.join(projectPath, 'package.json'), 'utf8'))
  # loop over values in file
  for key of envhash
    if packjson[key]
      envhash[key] = packjson[key]
    if process.env[key]
      envhash[key] = process.env[key]
  # return javascript module
  return "module.exports = " + JSON.stringify(envhash)

module.exports = compilers
