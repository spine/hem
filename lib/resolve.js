(function() {
  var Module, basename, dirname, extname, isAbsolute, join, modulerize, repl, resolve, _ref;
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
  repl = {
    id: 'repl',
    filename: join(process.cwd(), 'repl'),
    paths: module.paths
  };
  module.exports = function(request, parent) {
    var filename, id, path, paths, _i, _len, _ref2;
    if (parent == null) {
      parent = repl;
    }
    _ref2 = Module._resolveLookupPaths(request, parent), id = _ref2[0], paths = _ref2[1];
    filename = Module._findPath(request, paths);
    if (!filename) {
      throw new Error("Cannot find module '" + request + "'");
    }
    if (isAbsolute(id)) {
      paths = paths.sort(function(a, b) {
        return b.length - a.length;
      });
      for (_i = 0, _len = paths.length; _i < _len; _i++) {
        path = paths[_i];
        if (id.indexOf(path) !== -1) {
          id = id.replace(path + '/', '');
          break;
        }
      }
    }
    return [modulerize(id, filename), filename];
  };
  module.exports.paths = function(filename) {
    return Module._nodeModulePaths(dirname(filename));
  };
  module.exports.modulerize = modulerize;
}).call(this);
