(function() {
  var Slug, express, fs, hem, resolve, uglify;
  resolve = require('path').resolve;
  express = require('express');
  fs = require('fs');
  uglify = require('uglify-js');
  hem = require('./hem');
  Slug = (function() {
    Slug.prototype.defaults = {
      slug: './slug.json',
      main: './app/index',
      libs: [],
      public: './public',
      paths: ['./app'],
      port: process.env.PORT || 9294
    };
    function Slug(options) {
      var key, value, _base, _ref;
      this.options = options != null ? options : {};
      if (typeof this.options === 'string') {
        this.options = this.readSlug(this.options);
      }
      _ref = this.defaults;
      for (key in _ref) {
        value = _ref[key];
        (_base = this.options)[key] || (_base[key] = value);
      }
      this.options.public = resolve(this.options.public);
      this.addPaths(this.options.paths);
    }
    Slug.prototype.readSlug = function(path) {
      return JSON.parse(fs.readFileSync(path || this.options.slug, 'utf-8'));
    };
    Slug.prototype.server = function() {
      var server;
      server = express.createServer();
      server.get('/application.js', this.createPackage().createServer());
      server.use(express.static(this.options.public));
      server.listen(this.options.port);
      return this.options.port;
    };
    Slug.prototype.build = function() {
      var applicationPath, package;
      package = this.createPackage().compile();
      applicationPath = this.options.public + '/application.js';
      return fs.writeFileSync(applicationPath, package);
    };
    Slug.prototype.static = function() {
      var server;
      server = express.createServer();
      server.use(express.static(this.options.public));
      server.listen(this.options.port);
      return this.options.port;
    };
    Slug.prototype.addPaths = function(paths) {
      var path, _i, _len, _results;
      if (paths == null) {
        paths = [];
      }
      _results = [];
      for (_i = 0, _len = paths.length; _i < _len; _i++) {
        path = paths[_i];
        _results.push(require.paths.unshift(path));
      }
      return _results;
    };
    Slug.prototype.createPackage = function() {
      return hem.createPackage({
        require: this.options.main,
        libs: this.options.libs
      });
    };
    return Slug;
  })();
  module.exports = Slug;
}).call(this);
