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
      css: './css/index',
      cssOutputFile: 'application.css',
      skipCSS: false,
      libs: [],
      public: './public',
      jsOutputFile: 'application.js',
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
    }
    Slug.prototype.addLeadingSlash = function(path) {
      if (path.charAt(0) !== '/') {
        path = '/' + path;
      }
      return path;
    };
    Slug.prototype.server = function() {
      var server;
      server = express.createServer();
      if (!this.options.skipCSS) {
        server.get(this.addLeadingSlash(this.options.cssOutputFile), this.stylusPackage().createServer());
      }
      server.get(this.addLeadingSlash(this.options.jsOutputFile), this.hemPackage().createServer());
      server.use(express.static(this.options.public));
      return server.listen(this.options.port);
    };
    Slug.prototype.build = function() {
      var applicationPath, package;
      package = this.hemPackage().compile(true);
      applicationPath = this.options.public + this.addLeadingSlash(this.options.jsOutputFile);
      fs.writeFileSync(applicationPath, package);
      if (!this.options.skipCSS) {
        package = this.stylusPackage().compile(true);
        applicationPath = this.options.public + this.addLeadingSlash(this.options.cssOutputFile);
        return fs.writeFileSync(applicationPath, package);
      }
    };
    Slug.prototype.static = function() {
      var server;
      server = express.createServer();
      server.use(express.static(this.options.public));
      return server.listen(this.options.port);
    };
    Slug.prototype.stylusPackage = function() {
      return stylus.createPackage(this.options.css);
    };
    Slug.prototype.hemPackage = function() {
      return hem.createPackage({
        dependencies: this.options.dependencies,
        paths: this.options.paths,
        libs: this.options.libs
      });
    };
    return Slug;
  })();
  module.exports = Slug;
}).call(this);
