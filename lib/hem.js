(function() {
  var Hem, argv, compilers, css, fs, help, optimist, package, path, specs, strata;

  path = require('path');

  fs = require('fs');

  optimist = require('optimist');

  strata = require('strata');

  compilers = require('./compilers');

  package = require('./package');

  css = require('./css');

  specs = require('./specs');

  argv = optimist.usage(['  usage: hem COMMAND', '    server  start a dynamic development server', '    build   serialize application to disk', '    watch   build & watch disk for changes'].join("\n")).alias('p', 'port').alias('d', 'debug').argv;

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
      this.router = new strata.Router;
    }

    Hem.prototype.server = function() {
      var _this = this;
      this.app.use(strata.contentLength);
      this.router.get(this.options.cssPath, this.cssPackage().createServer());
      this.router.get(this.options.jsPath, this.hemPackage().createServer());
      if (path.existsSync(this.options.specs)) {
        this.router.get(this.options.specsPath, this.specsPackage().createServer());
      }
      if (path.existsSync(this.options.testPublic)) {
        this.app.map(this.options.testPath, function(app) {
          return app.use(strata.file, _this.options.testPublic, ['index.html', 'index.htm']);
        });
      }
      if (path.existsSync(this.options.public)) {
        this.app.use(strata.file, this.options.public, ['index.html', 'index.htm']);
      }
      this.app.run(this.router);
      if (process.env.PRODUCTION) {
        this.server = require(path.join(process.cwd(), this.serverOptions.production));
        if (this.server.initOnce) this.server.initOnce(this.app);
        if (this.server.router) this.app.run(this.server.router);
      } else if (this.serverOptions.paths.length > 0 && path.existsSync(this.serverOptions.paths[0])) {
        this.serverWatch();
        if (this.server && this.server.router) {
          this.app.run(function(env, callback) {
            if (_this.server.router) {
              return _this.server.router.call(env, callback);
            } else {
              return strata.utils.notFound(env, callback);
            }
          });
        }
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
      fs.writeFileSync(path.join(this.options.public, this.options.cssPath), source);
      if (this.serverOptions.paths.length > 0 && path.existsSync(this.serverOptions.paths[0])) {
        return console.log('You might need server code which needs to be compiled to ""./_server" use "cake build""');
      }
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

    Hem.prototype.serverBuild = function(first) {
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
      this.server = require(path.resolve(process.cwd(), this.serverOptions.paths[0]));
      if (this.server.initOnce && first) return this.server.initOnce(this.app);
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
      this.serverBuild(true);
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
            return _this.serverBuild(false);
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
