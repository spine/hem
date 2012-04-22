(function() {
  var EventEmitter, Hem, argv, cluster, compilers, css, eachWorkers, fs, help, numCPUs, optimist, package, path, specs, strata, sys,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  path = require('path');

  fs = require('fs');

  optimist = require('optimist');

  strata = require('strata');

  compilers = require('./compilers');

  package = require('./package');

  css = require('./css');

  specs = require('./specs');

  if (/^v0\.[012]/.test(process.version)) {
    sys = require("sys");
  } else {
    sys = require("util");
  }

  EventEmitter = require('events').EventEmitter;

  cluster = null;

  try {
    cluster = require('cluster');
    numCPUs = require('os').cpus().length;
  } catch (e) {

  }

  argv = optimist.usage(['  usage: hem COMMAND', '    server      start a dynamic development server', '    production  start a dynamic development server', '    build       serialize application to disk', '    watch       build & watch disk for changes'].join("\n")).alias('p', 'port').alias('d', 'debug').argv;

  help = function() {
    optimist.showHelp();
    return process.exit();
  };

  eachWorkers = function(cb) {
    var id, _results;
    if (cluster != null ? cluster.isMaster : void 0) {
      _results = [];
      for (id in cluster.workers) {
        if (cluster.workers.hasOwnProperty(id)) {
          _results.push(cb(cluster.workers[id]));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    }
  };

  Hem = (function(_super) {

    __extends(Hem, _super);

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
      host: process.env.HOST || argv.host || '0.0.0.0',
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
      if (cluster) {
        if (cluster.isMaster) {
          console.log('starting up master server... minimizing files...');
        }
      } else {
        console.log('starting up server... minimizing files...');
      }
      return this.server.apply(this, arguments);
    };

    Hem.prototype.doMapping = function(app) {
      var _this = this;
      return app.use(function(app) {
        if (!_this.serverApp) {
          _this.serverApp = app;
          _this.server.router.run(_this.serverApp);
        }
        return function(env, callback) {
          var _ref;
          if ((_ref = _this.server) != null ? _ref.router : void 0) {
            try {
              return _this.server.router.call(env, callback);
            } catch (e) {
              callback(500, {}, e.message);
              sys.puts(e.message);
              if (e.stack) return sys.puts(e.stack);
            }
          } else {
            return _this.serverApp(env, callback);
          }
        };
      });
    };

    Hem.prototype.server = function() {
      var i, mapped, self, worker, _results,
        _this = this;
      this.app.use(strata.contentLength);
      this.isProduction || (this.isProduction = process.env.PRODUCTION || (process.env.ENVIRONMENT === 'production'));
      if ((!cluster) || cluster.isMaster) {
        if (this.isProduction) {
          console.log('Running in production mode');
        } else {
          console.log('Running development server');
        }
      }
      if (this.serverOptions.paths.length > 0 && path.existsSync(this.serverOptions.paths[0])) {
        if (this.isProduction) {
          this.server = require(path.join(process.cwd(), this.serverOptions.paths[0]));
        } else {
          this.serverWatch();
        }
      }
      if (this.server && this.server.initOnce) this.server.initOnce(this.app);
      if (this.server && this.server.preInitOnce) {
        this.server.preInitOnce(this.app, this);
      }
      if (!this.isProduction) {
        this.watch();
      } else {
        if (!(cluster != null ? cluster.isWorker : void 0)) this.build();
      }
      mapped = false;
      if (path.existsSync(this.options.specs)) {
        this.app.map(this.options.specsPath, function(app) {
          return app.use(_this.specsPackage().createServer, _this.options.specsPath);
        });
      }
      if (path.existsSync(this.options.testPublic)) {
        this.app.map(this.options.testPath, function(app) {
          return app.use(strata.file, _this.options.testPublic, ['index.html', 'index.htm']);
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
      if (this.server && this.server.postInitOnce) {
        this.server.postInitOnce(this.app, this);
      }
      if (cluster && this.isProduction) {
        if (cluster.isMaster) {
          cluster.on('death', function(worker) {
            return console.log("worker " + worker.pid + " died");
          });
          console.log("master with " + numCPUs + " cpus");
          _results = [];
          for (i = 1; 1 <= numCPUs ? i <= numCPUs : i >= numCPUs; 1 <= numCPUs ? i++ : i--) {
            worker = cluster.fork();
            self = this;
            _results.push(worker.on('message', function(msg) {
              var obj, _ref;
              if (msg.cmd === 'hem:worker-online') {
                console.log("Worker: Worker " + worker.pid + " online");
                obj = {
                  'cmd': 'hem:busted-paths',
                  'data': self.bustedPaths
                };
                if ((_ref = this.process) != null ? _ref.send : void 0) {
                  return this.process.send(obj);
                } else {
                  return this.send(obj);
                }
              }
            }));
          }
          return _results;
        } else {
          process.on('message', function(msg) {
            if (msg.cmd === 'hem:busted-paths') {
              _this.bustedPaths = msg.data;
              console.log("Hashed files received " + _this.bustedPaths.css + " and " + _this.bustedPaths.js + " in " + _this.options.public);
              return _this.emit('bustedPaths', _this.bustedPaths);
            }
          });
          process.send({
            'cmd': 'hem:worker-online'
          });
          return strata.run(this.app, {
            port: this.options.port,
            host: this.options.host
          });
        }
      } else {
        return strata.run(this.app, {
          port: this.options.port,
          host: this.options.host
        });
      }
    };

    Hem.prototype.bustedName = function(p, bust) {
      var ext;
      ext = path.extname(p);
      return p + '-' + bust + ext;
    };

    Hem.prototype.build = function() {
      var bustedCssPath, bustedJsPath, source,
        _this = this;
      source = this.hemPackage().compile(this.isProduction);
      fs.writeFileSync(path.join(this.options.public, this.options.jsPath), source);
      bustedJsPath = this.bustedName(this.options.jsPath, this.hemPackage().cacheBust);
      fs.writeFileSync(path.join(this.options.public, bustedJsPath), source);
      source = this.cssPackage().compile();
      fs.writeFileSync(path.join(this.options.public, this.options.cssPath), source);
      bustedCssPath = this.bustedName(this.options.cssPath, this.cssPackage().cacheBust);
      fs.writeFileSync(path.join(this.options.public, bustedCssPath), source);
      this.bustedPaths = {
        "js": bustedJsPath,
        "css": bustedCssPath,
        "path": this.options.public
      };
      if (!this.isProduction) this.emit('bustedPaths', this.bustedPaths);
      eachWorkers(function(worker) {
        return worker.process.send('message', {
          'data': _this.bustedPaths,
          'cmd': 'hem:busted-paths'
        });
      });
      return console.log("Hashed files written to " + bustedCssPath + " and  " + bustedJsPath + " in " + this.options.public);
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
      _ref = (function() {
        var _j, _len, _ref, _results2;
        _ref = this.options.libs.concat(this.options.css, this.options.paths);
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
        if (fs.watch && process.platform !== 'darwin') {
          fs.watch(dir, function(event, file) {
            if (file) {
              console.log("" + file + " changed. Rebuilding.");
            } else {
              console.log("Something changed. Rebuilding.");
            }
            return _this.build();
          });
          _results.push(console.log('using fs.watch api to watch for changes'));
        } else {
          require('watch').watchTree(dir, function(file, curr, prev) {
            if (curr && (curr.nlink === 0 || +curr.mtime !== +(prev != null ? prev.mtime : void 0))) {
              console.log("" + file + " changed.  Rebuilding.");
              return _this.build();
            }
          });
          _results.push(console.log('using watch.watchTree api to watch for changes'));
        }
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
        if (fs.watch && process.platform !== 'darwin') {
          fs.watch(dir, function(event, file) {
            if (file) {
              return console.log("" + file + " changed. Rebuilding Server.");
            } else {
              return console.log("Somehing changed. Rebuilding Server.");
            }
          });
          _results.push(console.log('using fs.watch api to watch for server changes'));
        } else {
          require('watch').watchTree(dir, function(file, curr, prev) {
            if (curr && (curr.nlink === 0 || +curr.mtime !== +(prev != null ? prev.mtime : void 0))) {
              console.log("" + file + " changed.  Rebuilding Server.");
              return _this.serverBuild();
            }
          });
          _results.push(console.log('using watch.watchTree api to watch for server changes'));
        }
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

    Hem.prototype.cssPackage = function() {
      var pack;
      pack = css.createPackage(this.options.css);
      this.cssPackage = function() {
        return pack;
      };
      return pack;
    };

    Hem.prototype.hemPackage = function() {
      var pack;
      pack = package.createPackage({
        dependencies: this.options.dependencies,
        paths: this.options.paths,
        libs: this.options.libs
      });
      this.hemPackage = function() {
        return pack;
      };
      return pack;
    };

    Hem.prototype.specsPackage = function() {
      return this.specsPackage = specs.createPackage(this.options.specs);
    };

    return Hem;

  })(EventEmitter);

  module.exports = Hem;

}).call(this);
