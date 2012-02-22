(function() {
  var Dependency, Package, Stitch, compilers, crypto, eco, fs, stitch, sys, toArray, uglify, _ref,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  fs = require('fs');

  eco = require('eco');

  uglify = require('uglify-js');

  compilers = require('./compilers');

  stitch = require('../assets/stitch');

  Dependency = require('./dependency');

  Stitch = require('./stitch');

  toArray = require('./utils').toArray;

  sys = require((_ref = /^v0\.[012]/.test(process.version)) != null ? _ref : {
    "sys": "util"
  });

  crypto = require('crypto');

  Package = (function() {

    function Package(config) {
      if (config == null) config = {};
      this.createServer = __bind(this.createServer, this);
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
        var _i, _len, _ref2, _results;
        _ref2 = this.libs;
        _results = [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          path = _ref2[_i];
          _results.push(fs.readFileSync(path, 'utf8'));
        }
        return _results;
      }).call(this)).join("\n");
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

    Package.prototype.createServer = function(app, path) {
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
