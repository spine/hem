(function() {
  var Slug, express, fs, hem, resolve, stylus;
  resolve = require('path').resolve;
  express = require('express');
  fs = require('fs');
  hem = require('./hem');
  stylus = require('./stylus');
  Slug = (function() {
    Slug.prototype.defaults = {
      slug: './slug.json',
      main: './app/index',
      css: './css/index',
      libs: [],
      public: './public',
      paths: ['./app'],
      dependencies: [],
      port: process.env.PORT || 9294
    };
    Slug.readSlug = function(path) {
      return JSON.parse(fs.readFileSync(path, 'utf-8'));
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
    Slug.prototype.server = function() {
      var server;
      server = express.createServer();
      server.get('/application.css', this.stylusPackage().createServer());
      server.get('/application.js', this.hemPackage().createServer());
      server.use(express.static(this.options.public));
      return server.listen(this.options.port);
    };
    Slug.prototype.build = function() {
      var applicationPath, package;
      package = this.hemPackage().compile(true);
      applicationPath = this.options.public + '/application.js';
      fs.writeFileSync(applicationPath, package);
      package = this.stylusPackage().compile(true);
      applicationPath = this.options.public + '/application.css';
      return fs.writeFileSync(applicationPath, package);
    };
    Slug.prototype.static = function() {
      var server;
      server = express.createServer();
      server.use(express.static(this.options.public));
      return server.listen(this.options.port);
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
    Slug.prototype.stylusPackage = function() {
      return stylus.createPackage(this.options.css);
    };
    Slug.prototype.hemPackage = function() {
      var require;
      require = [].concat(this.options.dependencies);
      require.push(this.options.main);
      return hem.createPackage({
        require: require,
        libs: this.options.libs
      });
    };
    return Slug;
  })();
  module.exports = Slug;
}).call(this);
