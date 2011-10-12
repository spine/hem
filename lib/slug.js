(function() {
  var Slug, console, express, fs, hem, path, resolve, stylus, watch;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  resolve = require('path').resolve;
  express = require('express');
  fs = require('fs');
  hem = require('./hem');
  stylus = require('./stylus');
  path = require('path');
  watch = require('watch');
  console = require('console');
  Slug = (function() {
    Slug.prototype.defaults = {
      slug: './slug.json',
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
      try {
        package = this.hemPackage().compile(true);
        applicationPath = this.options.public + '/application.js';
        fs.writeFileSync(applicationPath, package);
        package = this.stylusPackage().compile(true);
        applicationPath = this.options.public + '/application.css';
        return fs.writeFileSync(applicationPath, package);
      } catch (error) {
        return console.error(error.stack);
      }
    };
    Slug.prototype.watch = function() {
      var dir, _i, _len, _ref, _results;
      this.build();
      _ref = [path.dirname(this.options.css)].concat(this.options.paths, this.options.libs);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dir = _ref[_i];
        _results.push(watch.watchTree(dir, __bind(function(file, n, o) {
          if (!(file instanceof Object) && (+n.mtime !== +(o != null ? o.mtime : void 0) || !n.nlink)) {
            console.log("" + file + " changed.  Rebuilding.");
            return this.build();
          }
        }, this)));
      }
      return _results;
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
