fs        = require('fs')
path      = require('path')
utils     = require('./utils')
compilers = {}

# TODO: wondering if we should make it so that the additional compilers are checked at runtime
# if the are present. One approach is to install hem inside the project using it. Or another is
# to require from the process.cwd() node_modules folder, assuming what is needed is installed there.
# TODO: look for it locally require(Module._findPath("spine", [process.cwd() + '/node_modules']))

compilers.js = compilers.css = (path) ->
  fs.readFileSync path, 'utf8'

require.extensions['.css'] = (module, filename) ->
  source = JSON.stringify(compilers.css(filename))
  module._compile "module.exports = #{source}", filename

try
  cs = require 'coffee-script'
  compilers.coffee    = (path) -> compileCoffeescript(path)
  compilers.litcoffee = (path) -> compileCoffeescript(path, true)
  compileCoffeescript = (path, literate = false) ->
    try
      cs.compile(fs.readFileSync(path, 'utf8'), filename: path, literate: literate)
    catch err
      err.message = "Coffeescript Error: " + err.message
      err.path    = "Coffeescript Path:  " + path
      err.path    = err.path + ":" + (err.location.first_line + 1) if err.location
      throw err
catch err

# TODO: make eco conditional with try/catch
eco = require 'eco'

compilers.eco = (path) ->
  content = eco.precompile fs.readFileSync path, 'utf8'
  """
  var content = #{content};
  module.exports = content;
  """

compilers.jeco = (path) -> 
  content = eco.precompile fs.readFileSync path, 'utf8'
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

compilers.html = (path) ->
  content = fs.readFileSync(path, 'utf8')
  "module.exports = #{JSON.stringify(content)};\n"

require.extensions['.html'] = (module, filename) ->
  module._compile compilers.html(filename), filename

try
  jade = require('jade')
  
  compilers.jade = (path) ->
    content = fs.readFileSync(path, 'utf8')
    try
      template = jade.compile content,
        filename: path
        # compileDebug: compilers.DEBUG
        client: true
      source = template.toString()
      "module.exports = #{source};"
    catch ex
      throw new Error("#{ex} in #{path}")

  require.extensions['.jade'] = (module, filename) ->
    module._compile compilers.jade(filename), filename
catch err

try
  stylus = require('stylus')
  
  compilers.styl = (_path) ->
    content = fs.readFileSync(_path, 'utf8')
    result = ''
    stylus(content)
      .include(path.dirname(_path))
      # TODO: are there other settings we should be looking at??
      .render((err, css) -> 
        throw err if err
        result = css
      )
    result
    
  require.extensions['.styl'] = (module, filename) -> 
    source = JSON.stringify(compilers.styl(filename))
    module._compile "module.exports = #{source}", filename
catch err

try
  less = require('less')

  compilers.less = (_path) ->
    content = fs.readFileSync(_path, 'utf8')
    result = ''
    less.render content, (err, css) ->
      throw err if err
      result = css
    result

  require.extensions['.less'] = (module, filename) -> 
    source = JSON.stringify(compilers.less(filename))
    module._compile "module.exports = #{source}", filename
catch err

# create a javascript module based off key values found in environment

compilers.env = (path) ->
  content  = fs.readFileSync(path, 'utf8')
  envhash  = JSON.parse(content)
  packjson = JSON.parse(fs.readFileSync('./package.json', 'utf8'))
  # loop over values in file
  for key of envhash
    if process.env[key]
      envhash[key] = process.env[key]
      utils.info "- Set env <yellow>#{key}</yellow> to <red>#{envhash[key]}</red>"
    if packjson[key]
      envhash[key] = packjson[key]
      utils.info "  - Set env <yellow>#{key}</yellow> to <red>#{envhash[key]}</red>"
  # return javascript module
  return "module.exports = " + JSON.stringify(envhash)

module.exports = compilers
