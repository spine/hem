(function() {
  var Dependency, Module, compilers, detective, extname, fs, mtime, resolve;
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
  Module = (function() {
    Module.walk = ['js', 'coffee'];
    function Module(request, parent) {
      var _ref;
      _ref = resolve(request, parent), this.id = _ref[0], this.filename = _ref[1];
      this.ext = extname(this.filename).slice(1);
      this.mtime = mtime(this.filename);
      this.paths = resolve.paths(this.filename);
    }
    Module.prototype.compile = function() {
      if (!this._compile || this.changed()) {
        this.mtime = mtime(this.filename);
        this._compile = compilers[this.ext](this.filename);
      }
      return this._compile;
    };
    Module.prototype.modules = function() {
      if (!this._modules || this.changed()) {
        this._modules = this.resolve();
      }
      return this._modules;
    };
    Module.prototype.changed = function() {
      return this.mtime !== mtime(this.filename);
    };
    Module.prototype.resolve = function() {
      var path, _i, _len, _ref, _results;
      _ref = this.calls();
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        path = _ref[_i];
        _results.push(new this.constructor(path, this));
      }
      return _results;
    };
    Module.prototype.calls = function() {
      var _ref;
      if (_ref = this.ext, __indexOf.call(this.constructor.walk, _ref) >= 0) {
        return detective(this.compile());
      } else {
        return [];
      }
    };
    return Module;
  })();
  Dependency = (function() {
    function Dependency(paths) {
      if (paths == null) {
        paths = [];
      }
      this.paths = paths;
    }
    Dependency.prototype.resolve = function() {
      var path;
      this.modules || (this.modules = (function() {
        var _i, _len, _ref, _results;
        _ref = this.paths;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          path = _ref[_i];
          _results.push(new Module(path));
        }
        return _results;
      }).call(this));
      return this.deepResolve(this.modules);
    };
    Dependency.prototype.deepResolve = function(modules, result, search) {
      var module, _i, _len;
      if (modules == null) {
        modules = [];
      }
      if (result == null) {
        result = [];
      }
      if (search == null) {
        search = {};
      }
      for (_i = 0, _len = modules.length; _i < _len; _i++) {
        module = modules[_i];
        if (!search[module.filename]) {
          search[module.filename] = true;
          result.push(module);
          this.deepResolve(module.modules(), result, search);
        }
      }
      return result;
    };
    return Dependency;
  })();
  module.exports = Dependency;
  module.exports.Module = Module;
}).call(this);
