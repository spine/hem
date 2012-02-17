(function() {
  var Specs, Stitch, stitch,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  stitch = require('../assets/stitch');

  Stitch = require('./stitch');

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
        if ((env.requestMethod !== 'GET') || (env.scriptName(istn(path)))) {
          app(env, callback);
          return;
        }
        return callback(200, {
          'Content-Type': 'text/javascript'
        }, _this.compile());
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
