(function() {
  var Module, basename, dirname, extname, isAbsolute, join, localPaths, modulePaths, modulerize, repl, resolve, _ref;
  Module = require('module');
  _ref = require('path'), join = _ref.join, extname = _ref.extname, dirname = _ref.dirname, basename = _ref.basename, resolve = _ref.resolve;
  isAbsolute = function(path) {
    return /^\//.test(path);
  };
  modulerize = function(id, filename) {
    var ext;
    if (filename == null) {
      filename = id;
    }
    ext = extname(filename);
    return join(dirname(id), basename(id, ext));
  };
  localPaths = Module._nodeModulePaths(process.cwd());
  modulePaths = module.paths.concat(localPaths);
  modulePaths = modulePaths.sort(function(a, b) {
    return b.length - a.length;
  });
  repl = {
    id: 'repl',
    filename: join(process.cwd(), 'repl'),
    paths: modulePaths
  };
  module.exports = function(request, parent) {
    var dir, filename, id, paths, _, _ref2;
    if (parent == null) {
      parent = repl;
    }
    _ref2 = Module._resolveLookupPaths(request, parent), _ = _ref2[0], paths = _ref2[1];
    filename = Module._findPath(request, paths);
    dir = filename;
    while (dir && modulePaths.indexOf(dir) === -1) {
      dir = dirname(dir);
    }
    id = filename.replace("" + dir + "/", '');
    return [modulerize(id, filename), filename];
  };
  module.exports.paths = function(filename) {
    return Module._nodeModulePaths(dirname(filename));
  };
  module.exports.modulerize = modulerize;
}).call(this);
