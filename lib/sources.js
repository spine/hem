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
      this.sources || (this.sources = Source.resolvePaths(this.paths));
      return this.resolveSources(this.sources);
    };
    Sources.prototype.resolveSources = function(sources, result, search) {
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
          this.resolveSources(source.sources(), result, search);
        }
      }
      return result;
    };
    return Sources;
  })();
  Source = (function() {
    Source.walk = ['js', 'coffee'];
    Source.resolvePaths = function(paths) {
      var path, results, source, _i, _j, _len, _len2, _ref;
      results = [];
      for (_i = 0, _len = paths.length; _i < _len; _i++) {
        path = paths[_i];
        _ref = this.resolve(path, '.');
        for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
          source = _ref[_j];
          results.push(source);
        }
      }
      return results;
    };
    Source.resolve = function(path, name, results) {
      var dep, source, _i, _len, _ref, _ref2;
      if (name == null) {
        name = '.';
      }
      if (results == null) {
        results = [];
      }
      _ref = resolve(name, path), name = _ref[0], path = _ref[1];
      source = new this(name, path);
      results.push(source);
      _ref2 = source.paths();
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        dep = _ref2[_i];
        this.resolve(dep, name, results);
      }
      return results;
    };
    function Source(name, path) {
      this.name = name;
      this.path = path;
      this.ext = extname(this.path).slice(1);
    }
    Source.prototype.compile = function() {
      if (!this.changed()) {
        return this._compile;
      }
      this.mtime = mtime(this.path);
      return this._compile = compilers[this.ext](this.path);
    };
    Source.prototype.sources = function() {
      if (!this._sources || this.changed()) {
        this._sources = this.constructor.resolvePaths(this.paths());
      }
      return this._sources;
    };
    Source.prototype.changed = function() {
      return !this.mtime || this.mtime !== mtime(this.path);
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
