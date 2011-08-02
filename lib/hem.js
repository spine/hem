(function() {
  var Package, Source, compilers, eco, fs, stitch;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  fs = require('fs');
  eco = require('eco');
  compilers = require('./compilers');
  stitch = require('../assets/stitch');
  Source = require('./source');
  Package = (function() {
    function Package(config) {
      var _ref, _ref2, _ref3;
      if (config == null) {
        config = {};
      }
      this.identifier = (_ref = config.identifier) != null ? _ref : 'require';
      this.libs = (_ref2 = config.libs) != null ? _ref2 : [];
      this.require = (_ref3 = config.require) != null ? _ref3 : [];
      if (typeof this.require === 'string') {
        this.require = [this.require];
      }
    }
    Package.prototype.compileSources = function() {
      var path, sources, _i, _len, _ref;
      sources = [];
      _ref = this.require;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        path = _ref[_i];
        sources = sources.concat(Source.resolve(path));
      }
      return stitch({
        identifier: this.identifier,
        sources: sources
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
    Package.prototype.compile = function() {
      return [this.compileLibs(), this.compileSources()].join("\n");
    };
    Package.prototype.createServer = function() {
      return __bind(function(req, res, next) {
        var content;
        content = this.compile();
        res.writeHead(200, {
          'Content-Type': 'text/javascript'
        });
        return res.end(content);
      }, this);
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
