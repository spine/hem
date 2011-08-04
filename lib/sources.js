(function() {
  var Source, Sources, compilers, detective, extname, fs, mtime, resolve;
  var __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  };
  extname = require('path').extname;
  fs = require('fs');
  detective = require('fast-detective');
  resolve = require('./resolve');
  compilers = require('./compilers');
  mtime = function(path) {
    return fs.statSync(path).mtime.valueOf();
  };
  Sources = (function() {
    function Sources(paths) {
      if (paths == null) {
        paths = [];
      }
      this.paths = paths;
    }
    Sources.prototype.resolve = function() {
      var path;
      this.sources || (this.sources = (function() {
        var _i, _len, _ref, _results;
        _ref = this.paths;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          path = _ref[_i];
          _results.push(new Source('.', path));
        }
        return _results;
      }).call(this));
      return this.deepResolve(this.sources);
    };
    Sources.prototype.deepResolve = function(sources, result, search) {
      var source, _i, _len;
      if (sources == null) {
        sources = [];
      }
      if (result == null) {
        result = [];
      }
      if (search == null) {
        search = {};
      }
      for (_i = 0, _len = sources.length; _i < _len; _i++) {
        source = sources[_i];
        if (!search[source.path]) {
          search[source.path] = true;
          result.push(source);
          this.deepResolve(source.sources(), result, search);
        }
      }
      return result;
    };
    return Sources;
  })();
  Source = (function() {
    Source.walk = ['js', 'coffee'];
    function Source(name, path) {
      var _ref;
      _ref = resolve(name, path), name = _ref[0], path = _ref[1];
      this.name = name;
      this.path = path;
      this.ext = extname(this.path).slice(1);
      this.mtime = mtime(this.path);
    }
    Source.prototype.compile = function() {
      if (!this._compile || this.changed()) {
        this.mtime = mtime(this.path);
        this._compile = compilers[this.ext](this.path);
      }
      return this._compile;
    };
    Source.prototype.sources = function() {
      if (!this._sources || this.changed()) {
        this._sources = this.resolve();
      }
      return this._sources;
    };
    Source.prototype.changed = function() {
      return this.mtime !== mtime(this.path);
    };
    Source.prototype.resolve = function() {
      var path, _i, _len, _ref, _results;
      _ref = this.paths();
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        path = _ref[_i];
        _results.push(new this.constructor(this.name, path));
      }
      return _results;
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
  module.exports = Sources;
}).call(this);
