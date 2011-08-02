(function() {
  var Source, compilers, detective, extname, resolve, wrap;
  var __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  };
  extname = require('path').extname;
  wrap = require('module').wrap;
  detective = require('detective');
  resolve = require('./resolve');
  compilers = require('./compilers');
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
      this.ext = extname(this.path).slice(1);
    }
    Source.prototype.compile = function() {
      return this._compile || (this._compile = compilers[this.ext](this.path));
    };
    Source.prototype.module = function() {
      return wrap(this.compile());
    };
    Source.prototype.paths = function() {
      var _ref;
      if (_ref = this.ext, __indexOf.call(this.constructor.walk, _ref) >= 0) {
        return detective(this.compile());
      } else {
        return [];
      }
    };
    return Source;
  })();
  module.exports = Source;
}).call(this);
