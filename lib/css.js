(function() {
  var CSS, compilers, resolve,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  resolve = require('path').resolve;

  compilers = require('./compilers');

  CSS = (function() {

    function CSS(path) {
      this.createServer = __bind(this.createServer, this);      try {
        this.path = require.resolve(resolve(path));
      } catch (e) {

      }
    }

    CSS.prototype.compile = function() {
      if (!this.path) return;
      delete require.cache[this.path];
      return require(this.path);
    };

    CSS.prototype.createServer = function(app, path) {
      var _this = this;
      return function(env, callback) {
        if ((env.requestMethod !== 'GET') || (env.scriptName !== path)) {
          app(env, callback);
          return;
        }
        return callback(200, {
          'Content-Type': 'text/css'
        }, _this.compile());
      };
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
