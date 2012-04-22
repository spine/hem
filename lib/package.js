(function() {
  var Dependency, Package, Stitch, compilers, crypto, eco, fs, stitch, sys, toArray, uglify;

  fs = require('fs');

  eco = require('eco');

  uglify = require('uglify-js');

  compilers = require('./compilers');

  stitch = require('../assets/stitch');

  Dependency = require('./dependency');

  Stitch = require('./stitch');

  toArray = require('./utils').toArray;

  if (/^v0\.[012]/.test(process.version)) {
    sys = require("sys");
  } else {
    sys = require("util");
  }

  crypto = require('crypto');

  Package = (function() {

    function Package(config) {
      if (config == null) config = {};
      this.identifier = config.identifier;
      this.libs = toArray(config.libs);
      this.paths = toArray(config.paths);
      this.dependencies = toArray(config.dependencies);
      this.cacheBust = '';
    }

    Package.prototype.compileModules = function() {
      this.dependency || (this.dependency = new Dependency(this.dependencies));
      this.stitch = new Stitch(this.paths);
      this.modules = this.dependency.resolve().concat(this.stitch.resolve());
      return stitch({
        identifier: this.identifier,
        modules: this.modules
      });
    };

    Package.prototype.compileLibs = function() {
      var path;
      return ((function() {
        var _i, _len, _ref, _results;
        _ref = this.libs;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          path = _ref[_i];
          _results.push(fs.readFileSync(path, 'utf8'));
        }
        return _results;
      }).call(this)).join("\n");
    };

    Package.prototype.refresh = function() {
      return this.compiled = null;
    };

    Package.prototype.compile = function(minify) {
      var result;
      result = [this.compileLibs(), this.compileModules()].join("\n");
      try {
        if (minify) result = uglify(result);
      } catch (e) {
        fs.writeFileSync("error.js", result);
        sys.puts("" + e.message + " at error.js:" + e.line + ":" + e.col);
        if (e.stack) sys.puts(e.stack);
      }
      this.cacheBust = crypto.createHash('md5').update(result).digest("hex");
      return result;
    };

    return Package;

  })();

  module.exports = {
    compilers: compilers,
    Package: Package,
    createPackage: function(config) {
      return new Package(config);
    }
  };

}).call(this);
