(function() {
  var Package, Source, commondir, compilers, cs, detective, eco, extname, fs, resolve, wrap;
  var __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  };
  extname = require('path').extname;
  wrap = require('module').wrap;
  fs = require('fs');
  detective = require('detective');
  commondir = require('commondir');
  resolve = require('./resolve');
  compilers = {
    js: function(path) {
      return fs.readFileSync(path, 'utf8');
    }
  };
  try {
    cs = require('coffee-script');
    compilers.coffee = function(path) {
      return cs.compile(fs.readFileSync(path, 'utf8'));
    };
  } catch (err) {

  }
  try {
    eco = require('eco');
    if (eco.precompile) {
      compilers.eco = function(path) {
        return eco.precompile(fs.readFileSync(path, 'utf8'));
      };
    }
  } catch (errr) {

  }
  Source = (function() {
    Source.walk = ['js', 'coffee'];
    Source.resolve = function(path, name, results) {
      var dep, key, source, value, _i, _len, _ref, _ref2, _results;
      if (name == null) {
        name = '.';
      }
      if (results == null) {
        results = {};
      }
      _ref = resolve(name, path), name = _ref[0], path = _ref[1];
      if (results[path]) {
        return;
      }
      results[path] = source = new this(name, path);
      _ref2 = source.paths();
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        dep = _ref2[_i];
        this.resolve(dep, name, results);
      }
      _results = [];
      for (key in results) {
        value = results[key];
        _results.push(value);
      }
      return _results;
    };
    function Source(name, path) {
      this.name = name;
      this.path = path;
      if (!this.valid()) {
        throw "no compiler: " + this.path;
      }
    }
    Source.prototype.ext = function() {
      return extname(this.path).slice(1);
    };
    Source.prototype.compile = function() {
      return this._compile || (this._compile = compilers[this.ext()](this.path));
    };
    Source.prototype.module = function() {
      return wrap(this.compile());
    };
    Source.prototype.paths = function() {
      var paths, _ref;
      if (_ref = this.ext(), __indexOf.call(this.constructor.walk, _ref) >= 0) {
        paths = detective.find(this.compile());
        if (paths.expressions.length) {
          throw 'Expressions in require() statements';
        }
        return paths.strings;
      } else {
        return [];
      }
    };
    Source.prototype.valid = function() {
      return !!compilers[this.ext()];
    };
    return Source;
  })();
  Package = (function() {
    function Package(config) {
      var _ref, _ref2, _ref3;
      if (config == null) {
        config = {};
      }
      this.identifier = (_ref = config.identifier) != null ? _ref : 'require';
      this.libs = (_ref2 = config.libs) != null ? _ref2 : ['./lib'];
      this.paths = (_ref3 = config.paths) != null ? _ref3 : ['./app/index'];
      if (typeof this.paths === 'string') {
        this.paths = [this.paths];
      }
    }
    Package.prototype.compile = function() {
      var path, source, sources, _i, _len, _ref;
      sources = [];
      _ref = this.paths;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        path = _ref[_i];
        sources = sources.concat(Source.resolve(path));
      }
      return ((function() {
        var _j, _len2, _results;
        _results = [];
        for (_j = 0, _len2 = sources.length; _j < _len2; _j++) {
          source = sources[_j];
          _results.push(source.module());
        }
        return _results;
      })()).join("\n");
    };
    return Package;
  })();
  module.exports = {
    compilers: compilers,
    Source: Source,
    Package: Package,
    createPackage: function(config) {
      return new Package(config);
    }
  };
}).call(this);
