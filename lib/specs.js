(function() {
  var Specs, Stitch, stitch;

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
      var _this = this;
      return function(env, callback) {
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
