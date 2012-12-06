fs        = require('fs')
path      = require('path')
compilers = {}

compilers.js = compilers.css = (path) ->
  fs.readFileSync path, 'utf8'

require.extensions['.css'] = (module, filename) ->
  source = JSON.stringify(compilers.css(filename))
  module._compile "module.exports = #{source}", filename

try
  cs = require 'coffee-script'
  compilers.coffee = (path) ->
    cs.compile(fs.readFileSync(path, 'utf8'), filename: path)
catch err

eco = require 'eco'

compilers.eco = (path) ->
  content = eco.precompile fs.readFileSync path, 'utf8'
  # TODO: wrap this in a function to be able to call jQuery
  # and store the module.id and values in the data attribute,
  # then have some way of calling replace with the same view
  # and function call with livereload
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

require.extensions['.jeco'] = require.extensions['.eco']
# require.extensions['.eco'] in eco package contains the function

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
        compileDebug: compilers.DEBUG
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
      .set('include css', true)
      .set('line-numbers', compilers.DEBUG)
      .set('firebug', ('--firebug' in process.argv))
      .render((err, css) -> 
        throw err if err
        result = css
      )
    result
    
  require.extensions['.styl'] = (module, filename) -> 
    source = JSON.stringify(compilers.styl(filename))
    module._compile "module.exports = #{source}", filename
catch err

module.exports = compilers
