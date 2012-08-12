(function() {
  var compilers, cs, dirname, eco, fs, jade, stylus;

  fs = require('fs');

  dirname = require('path').dirname;

  compilers = {};

  compilers.js = compilers.css = function(path) {
    return fs.readFileSync(path, 'utf8');
  };

  require.extensions['.css'] = function(module, filename) {
    var source;
    source = JSON.stringify(compilers.css(filename));
    return module._compile("module.exports = " + source, filename);
  };

  try {
    cs = require('coffee-script');
    compilers.coffee = function(path) {
      return cs.compile(fs.readFileSync(path, 'utf8'), {
        filename: path
      });
    };
  } catch (err) {

  }

  eco = require('eco');

  compilers.eco = function(path) {
    var content;
    content = eco.precompile(fs.readFileSync(path, 'utf8'));
    return "module.exports = " + content;
  };

  compilers.jeco = function(path) {
    var content;
    content = eco.precompile(fs.readFileSync(path, 'utf8'));
    return "module.exports = function(values){ \n  var $  = jQuery, result = $();\n  values = $.makeArray(values);\n  \n  for(var i=0; i < values.length; i++) {\n    var value = values[i];\n    var elem  = $((" + content + ")(value));\n    elem.data('item', value);\n    $.merge(result, elem);\n  }\n  return result;\n};";
  };

  require.extensions['.jeco'] = require.extensions['.eco'];

  compilers.tmpl = function(path) {
    var content;
    content = fs.readFileSync(path, 'utf8');
    return ("var template = jQuery.template(" + (JSON.stringify(content)) + ");\n") + "module.exports = (function(data){ return jQuery.tmpl(template, data); });\n";
  };

  require.extensions['.tmpl'] = function(module, filename) {
    return module._compile(compilers.tmpl(filename));
  };

  try {
    stylus = require('stylus');
    compilers.styl = function(path) {
      var content, result;
      content = fs.readFileSync(path, 'utf8');
      result = '';
      stylus(content).include(dirname(path)).render(function(err, css) {
        if (err) throw err;
        return result = css;
      });
      return result;
    };
    require.extensions['.styl'] = function(module, filename) {
      var source;
      source = JSON.stringify(compilers.styl(filename));
      return module._compile("module.exports = " + source, filename);
    };
  } catch (err) {

  }

  compilers.html = function(path) {
    var content;
    content = fs.readFileSync(path, 'utf8');
    return "module.exports = " + (JSON.stringify(content)) + ";\n";
  };

  require.extensions['.html'] = function(module, filename) {
    return module._compile(compilers.html(filename), filename);
  };

  try {
    jade = require('jade');
    compilers.jade = function(path) {
      var content, html, locals, options, template;
      content = fs.readFileSync(path, 'utf8');
      options = {};
      template = jade.compile(content, options);
      locals = {};
      html = template(locals);
      return "module.exports = " + (JSON.stringify(html)) + ";\n";
    };
    require.extensions['.jade'] = function(module, filename) {
      return module._compile(compilers.jade(filename), filename);
    };
  } catch (err) {

  }

  module.exports = compilers;

}).call(this);
