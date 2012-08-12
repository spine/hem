(function() {
  var CSS, compilers, resolve;

  resolve = require('path').resolve;

  compilers = require('./compilers');

  CSS = (function() {

    function CSS(path) {
      try {
        this.path = require.resolve(resolve(path));
      } catch (e) {

      }
    }

    CSS.prototype.compile = function() {
      if (!this.path) return;
      delete require.cache[this.path];
      return require(this.path);
    };

    CSS.prototype.createServer = function() {
      var _this = this;
      return function(env, callback) {
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
