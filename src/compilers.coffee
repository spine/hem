fs        = require('fs')
{dirname} = require('path')
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
  "module.exports = #{content}"

compilers.jeco = (path) -> 
  content = eco.precompile fs.readFileSync path, 'utf8'
  """
  module.exports = function(values){ 
    var $  = jQuery, result = $();
    values = $.makeArray(values);
    
    for(var i=0; i < values.length; i++) {
      var value = values[i];
      var elem  = $((#{content})(value));
      elem.data('item', value);
      $.merge(result, elem);
    }
    return result;
  };
  """

require.extensions['.jeco'] = require.extensions['.eco']

compilers.tmpl = (path) ->
  content = fs.readFileSync(path, 'utf8')
  "var template = jQuery.template(#{JSON.stringify(content)});\n" +
  "module.exports = (function(data){ return jQuery.tmpl(template, data); });\n"

require.extensions['.tmpl'] = (module, filename) -> 
  module._compile(compilers.tmpl(filename))
  
try
  stylus = require('stylus')
  
  compilers.styl = (path) ->
    content = fs.readFileSync(path, 'utf8')
    result = ''
    stylus(content)
      .include(dirname(path))
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