(function() {
  var CSS, compilers, crypto, resolve, sys,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  resolve = require('path').resolve;

  compilers = require('./compilers');

  crypto = require('crypto');

  if (/^v0\.[012]/.test(process.version)) {
    sys = require("sys");
  } else {
    sys = require("util");
  }

  CSS = (function() {

    function CSS(path) {
      this.createServer = __bind(this.createServer, this);      this.cacheBust = '';
      try {
        this.path = require.resolve(resolve(path));
      } catch (e) {

      }
    }

    CSS.prototype.compile = function() {
      var result;
      if (!this.path) return;
      delete require.cache[this.path];
      result = require(this.path);
      this.cacheBust = crypto.createHash('md5').update(result).digest("hex");
      return result;
    };

    CSS.prototype.refresh = function() {
      return this.compiled = null;
    };

    CSS.prototype.createServer = function(app, path) {
      var _this = this;
      return function(env, callback) {
        try {
          if ((env.requestMethod !== 'GET') || (env.scriptName.substr(0, path.length - 1) === path)) {
            app(env, callback);
            return;
          }
          if (!_this.compiled) {
            console.log("compiling css");
            _this.compiled = _this.compile();
          }
          return callback(200, {
            'Content-Type': 'text/css'
          }, _this.compiled);
        } catch (e) {
          sys.puts(e.message);
          if (e.stack) sys.puts(e.stack);
          return callback(500, {}, e.message);
        }
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
