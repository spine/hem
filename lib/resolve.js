(function() {
  var Module, basename, dirname, extname, invalidDirs, isAbsolute, isWindows, join, modulePaths, modulerize, pathSeparator, repl, resolve, _ref,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Module = require('module');

  _ref = require('path'), join = _ref.join, extname = _ref.extname, dirname = _ref.dirname, basename = _ref.basename, resolve = _ref.resolve;

  isAbsolute = function(path) {
    return /^\//.test(path);
  };

  isWindows = process.platform === 'win32';

  pathSeparator = isWindows ? '\\' : '/';

  modulerize = function(id, filename) {
    var ext, modName;
    if (filename == null) filename = id;
    ext = extname(filename);
    modName = join(dirname(id), basename(id, ext));
    if (isWindows) modName = modName.replace(/\\/g, '/');
    return modName;
  };

  modulePaths = Module._nodeModulePaths(process.cwd());

  invalidDirs = [pathSeparator, '.'];

  repl = {
    id: 'repl',
    filename: join(process.cwd(), 'repl'),
    paths: modulePaths
  };

  module.exports = function(request, parent) {
    var dir, filename, id, paths, _, _ref2;
    if (parent == null) parent = repl;
    _ref2 = Module._resolveLookupPaths(request, parent), _ = _ref2[0], paths = _ref2[1];
    filename = Module._findPath(request, paths);
    dir = filename;
    if (!filename) {
      throw "Cannot find module: " + request + ". Have you run `npm install .` ?";
    }
    while (__indexOf.call(invalidDirs, dir) < 0 && __indexOf.call(modulePaths, dir) < 0) {
      dir = dirname(dir);
    }
    if (__indexOf.call(invalidDirs, dir) >= 0) {
      throw "Load path not found for " + filename;
    }
    id = filename.replace("" + (dir + pathSeparator), '');
    return [modulerize(id, filename), filename];
  };

  module.exports.pathSeparator = pathSeparator;

  module.exports.paths = function(filename) {
    return Module._nodeModulePaths(dirname(filename));
  };

  module.exports.modulerize = modulerize;

}).call(this);
