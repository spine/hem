(function() {
  var Hem, argv, compilers, css, fs, help, optimist, package, path, specs, strata;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  path = require('path');
  fs = require('fs');
  optimist = require('optimist');
  strata = require('strata');
  compilers = require('./compilers');
  package = require('./package');
  css = require('./css');
  specs = require('./specs');
  optimist.usage(['  usage: hem COMMAND', '    server  start a dynamic development server', '    build   serialize application to disk', '    watch   build & watch disk for changes'].join("\n")).alias('p', 'port');
  argv = optimist.argv;
  help = function() {
    optimist.showHelp();
    return process.exit();
  };
  Hem = (function() {
    Hem.exec = function(command, options) {
      return (new this(options)).exec(command);
    };
    Hem.include = function(props) {
      var key, value, _results;
      _results = [];
      for (key in props) {
        value = props[key];
        _results.push(this.prototype[key] = value);
      }
      return _results;
    };
    Hem.prototype.compilers = compilers;
    Hem.prototype.options = {
      slug: './slug.json',
      css: './css',
      libs: [],
      public: './public',
      paths: ['./app'],
      dependencies: [],
      port: process.env.PORT || argv.port || 9294,
      cssPath: '/application.css',
      jsPath: '/application.js',
      test: './test',
      testPublic: './test/public',
      testPath: '/test',
      specs: './test/specs',
      specsPath: '/test/specs.js'
    };
    function Hem(options) {
      var key, value, _ref;
      if (options == null) {
        options = {};
      }
      this.specsPackage = __bind(this.specsPackage, this);
      this.hemPackage = __bind(this.hemPackage, this);
      this.cssPackage = __bind(this.cssPackage, this);
      this.readSlug = __bind(this.readSlug, this);
      this.exec = __bind(this.exec, this);
      this.watch = __bind(this.watch, this);
      this.build = __bind(this.build, this);
      this.server = __bind(this.server, this);
      for (key in options) {
        value = options[key];
        this.options[key] = value;
      }
      _ref = this.readSlug();
      for (key in _ref) {
        value = _ref[key];
        this.options[key] = value;
      }
      this.app = new strata.Builder;
    }
    Hem.prototype.server = function() {
      this.app.use(strata.contentLength);
      if (this.options.css) {
        this.app.get(this.options.cssPath, this.cssPackage().createServer());
      }
      this.app.get(this.options.jsPath, this.hemPackage().createServer());
      this.app.get(this.options.specsPath, this.specsPackage().createServer());
      this.app.map(this.options.testPath, __bind(function(app) {
        return this.app.use(strata.static, this.options.testPublic);
      }, this));
      this.app.use(strata.static, this.options.public);
      return strata.run(this.app, {
        port: this.options.port
      });
    };
    Hem.prototype.build = function() {
      var source;
      source = this.hemPackage().compile(true);
      fs.writeFileSync(path.join(this.options.public, this.options.jsPath), source);
      if (this.options.css) {
        source = this.cssPackage().compile();
        return fs.writeFileSync(path.join(this.options.public, this.options.cssPath), source);
      }
    };
    Hem.prototype.watch = function() {
      var cssDir, dir, lib, libDir, _i, _j, _len, _len2, _ref, _ref2, _results;
      this.build();
      cssDir = this.options.css ? [this.options.css] : [];
      libDir = [];
      _ref = this.options.libs;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        lib = _ref[_i];
        libDir.push(path.dirname(lib));
      }
      _ref2 = cssDir.concat(this.options.paths, libDir);
      _results = [];
      for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
        dir = _ref2[_j];
        _results.push(require('watch').watchTree(dir, __bind(function(file, curr, prev) {
          if (curr && (curr.nlink === 0 || +curr.mtime !== +(prev != null ? prev.mtime : void 0))) {
            console.log("" + file + " changed.  Rebuilding.");
            return this.build();
          }
        }, this)));
      }
      return _results;
    };
    Hem.prototype.exec = function(command) {
      if (command == null) {
        command = argv._[0];
      }
      if (!this[command]) {
        return help();
      }
      this[command]();
      return console.log((function() {
        switch (command) {
          case 'server':
            return "Starting server on: " + this.options.port;
            break;
          case 'build':
            return 'Built application';
          case 'watch':
            return 'Watching application';
        }
      }).call(this));
    };
    Hem.prototype.readSlug = function(slug) {
      if (slug == null) {
        slug = this.options.slug;
      }
      if (!(slug && path.existsSync(slug))) {
        return {};
      }
      return JSON.parse(fs.readFileSync(slug, 'utf-8'));
    };
    Hem.prototype.cssPackage = function() {
      return css.createPackage(this.options.css);
    };
    Hem.prototype.hemPackage = function() {
      return package.createPackage({
        dependencies: this.options.dependencies,
        paths: this.options.paths,
        libs: this.options.libs
      });
    };
    Hem.prototype.specsPackage = function() {
      return specs.createPackage(this.options.specs);
    };
    return Hem;
  })();
  module.exports = Hem;
}).call(this);
