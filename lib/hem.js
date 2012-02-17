(function() {
  var Hem, argv, compilers, css, fs, help, optimist, package, path, specs, strata, sys;

  path = require('path');

  fs = require('fs');

  optimist = require('optimist');

  strata = require('strata');

  compilers = require('./compilers');

  package = require('./package');

  css = require('./css');

  specs = require('./specs');

  sys = require('sys');

  argv = optimist.usage(['  usage: hem COMMAND', '    server      start a dynamic development server', '    production  start a dynamic development server', '    build       serialize application to disk', '    watch       build & watch disk for changes'].join("\n")).alias('p', 'port').alias('d', 'debug').argv;

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

    Hem.prototype.serverOptions = {
      paths: ['./server']
    };

    Hem.prototype.options = {
      slug: './slug.json',
      serverSlug: './serverSlug.json',
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

    Hem.prototype.isProdution = false;

    Hem.prototype.newRouter = false;

    function Hem(options) {
      var key, value, _ref, _ref2;
      if (options == null) options = {};
      for (key in options) {
        value = options[key];
        this.options[key] = value;
      }
      _ref = this.readSlug();
      for (key in _ref) {
        value = _ref[key];
        this.options[key] = value;
      }
      _ref2 = this.readSlug(this.options.serverSlug);
      for (key in _ref2) {
        value = _ref2[key];
        this.serverOptions[key] = value;
      }
      this.app = new strata.Builder;
    }

    Hem.prototype.production = function() {
      this.isProduction = true;
      return this.server.apply(this, arguments);
    };

    Hem.prototype.doMapping = function(app) {
      var _this = this;
      return app.use(function(app) {
        return function(env, callback) {
          var _ref;
          if ((_ref = _this.server) != null ? _ref.router : void 0) {
            return _this.server.router.call(env, callback);
          } else {
            return app(env, callback);
          }
        };
      });
    };

    Hem.prototype.server = function() {
      var mapped,
        _this = this;
      this.app.use(strata.contentLength);
      this.isProduction || (this.isProduction = process.env.PRODUCTION || (process.env.ENVIRONMENT === 'production'));
      if (this.serverOptions.paths.length > 0 && path.existsSync(this.serverOptions.paths[0])) {
        if (this.isProduction) {
          this.server = require(path.join(process.cwd(), this.serverOptions.paths[0]));
        } else {
          this.serverWatch();
        }
      }
      if (this.server && this.server.initOnce) this.server.initOnce(this.app);
      if (this.server && this.server.preInitOnce) {
        this.server.preInitOnce(this.app);
      }
      if (!this.isProduction) {
        this.app.map(this.options.cssPath, function(app) {
          return app.use(_this.cssPackage().createServer, _this.options.cssPath);
        });
        this.app.map(this.options.jsPath, function(app) {
          return app.use(_this.hemPackage().createServer, _this.options.jsPath);
        });
        if (path.existsSync(this.options.specs)) {
          this.app.map(this.options.specsPath, function(app) {
            return app.use(_this.specsPackage().createServer, _this.options.specsPath);
          });
        }
      }
      mapped = false;
      if (path.existsSync(this.options.testPublic)) {
        mapped = true;
        this.app.map(this.options.testPath, function(app) {
          app.use(strata.file, _this.options.testPublic, ['index.html', 'index.htm']);
          return _this.doMapping(app);
        });
      }
      if (path.existsSync(this.options.public)) {
        mapped = true;
        this.app.map('/', function(app) {
          app.use(strata.file, _this.options.public, ['index.html', 'index.htm']);
          return _this.doMapping(app);
        });
      }
      if (!mapped) {
        this.app.map('/', function(app) {
          return _this.doMapping(app);
        });
      }
      if (this.server && this.server.preInitOnce) {
        this.server.postInitOnce(this.app);
      }
      return strata.run(this.app, {
        port: this.options.port
      });
    };

    Hem.prototype.build = function() {
      var source;
      source = this.hemPackage().compile(!argv.debug);
      fs.writeFileSync(path.join(this.options.public, this.options.jsPath), source);
      source = this.cssPackage().compile();
      return fs.writeFileSync(path.join(this.options.public, this.options.cssPath), source);
    };

    Hem.prototype.clearCacheForDir = function(dir) {
      var file, key, p, stat, _i, _len, _ref, _results;
      _ref = fs.readdirSync(dir);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        file = _ref[_i];
        if (file === '.' || file === '..') continue;
        p = path.join(dir, file);
        stat = fs.statSync(p);
        if (stat.isDirectory()) {
          _results.push(this.clearCacheForDir(p));
        } else {
          try {
            key = require.resolve(p);
            _results.push(delete require.cache[key]);
          } catch (e) {

          }
        }
      }
      return _results;
    };

    Hem.prototype.serverBuild = function() {
      var dir, lib, _i, _len, _ref;
      _ref = (function() {
        var _j, _len, _ref, _results;
        _ref = this.serverOptions.paths;
        _results = [];
        for (_j = 0, _len = _ref.length; _j < _len; _j++) {
          lib = _ref[_j];
          _results.push(path.join(process.cwd(), lib));
        }
        return _results;
      }).call(this);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dir = _ref[_i];
        this.clearCacheForDir(dir);
      }
      try {
        return this.server = require(path.resolve(process.cwd(), this.serverOptions.paths[0]));
      } catch (e) {
        sys.puts(e.message);
        if (e.stack) return sys.puts(e.stack);
      }
    };

    Hem.prototype.watch = function() {
      var dir, lib, _i, _len, _ref, _results,
        _this = this;
      this.build();
      _ref = ((function() {
        var _j, _len, _ref, _results2;
        _ref = this.options.libs;
        _results2 = [];
        for (_j = 0, _len = _ref.length; _j < _len; _j++) {
          lib = _ref[_j];
          _results2.push(path.dirname(lib));
        }
        return _results2;
      }).call(this)).concat(this.options.css, this.options.paths);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dir = _ref[_i];
        if (!path.existsSync(dir)) continue;
        _results.push(require('watch').watchTree(dir, function(file, curr, prev) {
          if (curr && (curr.nlink === 0 || +curr.mtime !== +(prev != null ? prev.mtime : void 0))) {
            console.log("" + file + " changed.  Rebuilding.");
            return _this.build();
          }
        }));
      }
      return _results;
    };

    Hem.prototype.serverWatch = function() {
      var dir, lib, _i, _len, _ref, _results,
        _this = this;
      this.serverBuild();
      _ref = (function() {
        var _j, _len, _ref, _results2;
        _ref = this.serverOptions.paths;
        _results2 = [];
        for (_j = 0, _len = _ref.length; _j < _len; _j++) {
          lib = _ref[_j];
          _results2.push(path.resolve(process.cwd(), lib));
        }
        return _results2;
      }).call(this);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dir = _ref[_i];
        if (!path.existsSync(dir)) continue;
        _results.push(require('watch').watchTree(dir, function(file, curr, prev) {
          if (curr && (curr.nlink === 0 || +curr.mtime !== +(prev != null ? prev.mtime : void 0))) {
            console.log("" + file + " changed.  Rebuilding Server.");
            return _this.serverBuild();
          }
        }));
      }
      return _results;
    };

    Hem.prototype.exec = function(command) {
      if (command == null) command = argv._[0];
      if (!this[command]) return help();
      this[command]();
      switch (command) {
        case 'build':
          return console.log('Built application');
        case 'watch':
          return console.log('Watching application');
      }
    };

    Hem.prototype.readSlug = function(slug) {
      if (slug == null) slug = this.options.slug;
      if (!(slug && path.existsSync(slug))) return {};
      return JSON.parse(fs.readFileSync(slug, 'utf-8'));
    };

    Hem.prototype.serverPackage = function() {
      return package.createPackage(this.serverOptions);
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
