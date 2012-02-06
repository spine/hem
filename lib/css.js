(function() {
  var CSS, compilers, resolve, toArray;

  resolve = require('path').resolve;

  compilers = require('./compilers');

  toArray = require('./utils').toArray;

  CSS = (function() {

    function CSS(paths) {
      this.paths = toArray(paths).map(this.try_resolve).filter((function(path) {
        return !!path;
      }));
    }

    CSS.prototype.compile = function() {
      return this.paths.map(function(path) {
        delete require.cache[path];
        return require(path);
      }).join('');
    };

    CSS.prototype.createServer = function() {
      var _this = this;
      return function(env, callback) {
        return callback(200, {
          'Content-Type': 'text/css'
        }, _this.compile());
      };
    };

    CSS.prototype.try_resolve = function(file) {
      try {
        file = require.resolve(resolve(file));
        return file;
      } catch (e) {
        console.log(e);
      }
      return null;
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
