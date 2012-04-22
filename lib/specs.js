(function() {
  var Specs, Stitch, stitch, sys,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  stitch = require('../assets/stitch');

  Stitch = require('./stitch');

  if (/^v0\.[012]/.test(process.version)) {
    sys = require("sys");
  } else {
    sys = require("util");
  }

  Specs = (function() {

    function Specs(path) {
      this.path = path;
      this.createServer = __bind(this.createServer, this);
    }

    Specs.prototype.compile = function() {
      this.stitch = new Stitch([this.path]);
      return stitch({
        identifier: 'specs',
        modules: this.stitch.resolve()
      });
    };

    Specs.prototype.createServer = function(app, path) {
      var _this = this;
      return function(env, callback) {
        var content;
        try {
          if ((env.requestMethod !== 'GET') || (env.scriptName.substr(0, path.length - 1) === path)) {
            app(env, callback);
            return;
          }
          content = _this.compile();
          return callback(200, {
            'Content-Type': 'text/javascript'
          }, content);
        } catch (e) {
          sys.puts(e.message);
          if (e.stack) sys.puts(e.stack);
          return callback(500, {}, e.message);
        }
      };
    };

    return Specs;

  })();

  module.exports = {
    Specs: Specs,
    createPackage: function(path) {
      return new Specs(path);
    }
  };

}).call(this);
