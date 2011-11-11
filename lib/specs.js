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
        identifier: this.identifier,
        modules: this.stitch.resolve()
      });
    };
    Specs.prototype.createServer = function() {
      return __bind(function(req, res, next) {
        var content;
        content = this.compile();
        res.writeHead(200, {
          'Content-Type': 'text/javascript'
        });
        return res.end(content);
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
