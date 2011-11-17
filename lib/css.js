(function() {
  var CSS, compilers, resolve;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  resolve = require('path').resolve;
  compilers = require('./compilers');
  CSS = (function() {
    function CSS(path) {
      this.path = resolve(path);
      this.path = require.resolve(this.path);
    }
    CSS.prototype.compile = function() {
      delete require.cache[this.path];
      return require(this.path);
    };
    CSS.prototype.createServer = function() {
      return __bind(function(req, res, next) {
        return callback(200, {
          'Content-Type': 'text/css'
        }, this.compile());
      }, this);
    };
    return CSS;
  })();
  module.exports = {
    CSS: CSS,
    createPackage: function(path) {
      return new CSS(path);
    }
  };
}).call(this);
