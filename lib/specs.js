(function() {
  var Specs, Stitch, stitch;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  stitch = require('../assets/stitch');
  Stitch = require('./stitch');
  Specs = (function() {
    function Specs(path) {
      this.path = path;
    }
    Specs.prototype.compile = function() {
      this.stitch = new Stitch([this.path]);
      return stitch({
        identifier: 'specs',
        modules: this.stitch.resolve()
      });
    };
    Specs.prototype.createServer = function() {
      return __bind(function(env, callback) {
        return callback(200, {
          'Content-Type': 'text/javascript'
        }, this.compile());
      }, this);
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
