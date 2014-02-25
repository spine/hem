fs        = require('fs')
path      = require('path')
log       = require('./log')
compilers = {}
lmCache   = {}

# argv is set when hem first loads up

compilers.argv = {}

# Load the modules from the project directory (instead of from the hem
# node_modules). This allows a lot of the different javascript/css pre
# compilers to be installed in the project vs having to be included with
# the hem package.

# setup project path
projectPath = path.resolve process.cwd()

# TODO: test to make sure the project path contains a node_modules folder??
# TODO: come up with consistant error object to throw on compile errors
#       handleError(ex, compilerName, _path) -> do stuff...
# TODO: not sure if we need extension set anymore since we just use compile!!
# TODO: separete js/css compilers??

# helper fuction to perform load/caching of modules from 
# the project folder, will quit if unable to load...
requireLocalModule = (localModule, _path) ->
  modulePath = "#{projectPath}/node_modules/#{localModule}"
  try
    lmCache[localModule] or= require modulePath
  catch error
    relativePath = path.relative(projectPath, _path)
    log.error("Unable to load <green>#{localModule}</green> module to compile <yellow>#{relativePath}</yellow>")
    log.error("Try to use 'npm install #{localModule}' in your project directory.")
    log.error(error, false) if log.VERBOSE
    process.exit()

class CompileError extends Error
  constructor: (message, _path, ex) -> 
    super
    @name = "CompileError"
    @path = _path
    @ex   = ex

##
## Basic javascript/css files
##

compilers.js = compilers.css = (_path) ->
  fs.readFileSync _path, 'utf8'

require.extensions['.css'] = (module, filename) ->
  source = JSON.stringify(compilers.css(filename))
  module._compile "module.exports = #{source}", filename

##
## HTML and Tmpl files
##

compilers.html = (_path) ->
  content = fs.readFileSync(_path, 'utf8')
  "module.exports = #{JSON.stringify(content)};\n"

require.extensions['.html'] = (module, filename) ->
  module._compile compilers.html(filename), filename

require.extensions['.tmpl'] = (module, filename) ->
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
    throw new CompileError("Coffeescript: " + ex.message, _path, err)

##
## Compile Handlebars
##

compilers.hbs = (_path) ->
  handlebars = requireLocalModule('handlebars', _path)
  try
    content  = fs.readFileSync(path, 'utf8')
    template = handlebars.precompile content,
         separator: '\n'
         knownHelpers: []
         knownHelpersOnly: false
    source = template.toString()
    "module.exports = Handlebars.template(#{source});"
  catch err
    throw new CompileError("handlebars: " + ex.message, _path, err)

require.extensions['.hbs'] = (module, filename) ->
  module._compile compilers.hbs(filename), filename

##
## Eco and Jeco Compiler
##

compilers.eco = (_path) ->
  eco = requireLocalModule('eco', _path)
  try
    content = eco.precompile fs.readFileSync _path, 'utf8'
    """
    var content = #{content};
    module.exports = content;
    """
  catch err
    throw new CompileError("eco Error: " + ex.message, _path, err)

compilers.jeco = (_path) ->
  eco = requireLocalModule('eco', _path)
  try
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
  catch err
    throw new CompileError("jeco: " + err.message, _path, err)

# require.extensions['.eco'] in eco package contains require.extensions setup
require.extensions['.jeco'] = require.extensions['.eco']

##
## Jade Compiler
##

compilers.jade = (_path) ->
  jade    = requireLocalModule('jade', _path)
  content = fs.readFileSync(_path, 'utf8')
  try
     # look first for compileClient (starting with jade v1.0.0) and fallback compile if not defined
    jCompile = jade.compileClient or jade.compile
    template = jCompile content,
      filename: _path
      compileDebug: @argv.command is "server"
      client: true
    source = template.toString()
    "module.exports = #{source};"
  catch err
    throw new CompileError("jade: #{err.message}", _path, err)

require.extensions['.jade'] = (module, filename) ->
  module._compile compilers.jade(filename), filename

##
## Stylus Compiler
##

compilers.stylus = compilers.styl = (_path) ->
  stylus  = requireLocalModule('stylus', _path)
  try
    content = fs.readFileSync(_path, 'utf8')
    result  = ''
    stylus(content)
      .include(path.dirname(_path))
      .render((err, css) ->
        throw err if err
        result = css
      )
    result
  catch err
    throw new CompileError("stylus: #{err.message}", _path, err)


require.extensions['.styl'] = (module, filename) ->
  source = JSON.stringify(compilers.stylus(filename))
  module._compile "module.exports = #{source}", filename

##
## Less Compiler
##

compilers.less = (_path) ->
  less    = requireLocalModule('less', _path)
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
