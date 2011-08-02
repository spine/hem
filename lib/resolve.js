(function() {
  var basename, dirname, extname, getPackagePath, isAbsolute, isPackage, isRelative, join, namify, normalize, resolve, _ref;
  _ref = require('path'), join = _ref.join, normalize = _ref.normalize, resolve = _ref.resolve, extname = _ref.extname, dirname = _ref.dirname, basename = _ref.basename;
  isAbsolute = function(path) {
    return /^\//.test(path);
  };
  isRelative = function(path) {
    return /^\.\//.test(path);
  };
  isPackage = function(path) {
    return !/\//.test(path);
  };
  namify = function(path) {
    var ext;
    path = normalize(path);
    ext = extname(path);
    return join(dirname(path), basename(path, ext));
  };
  getPackagePath = function(path) {
    var package;
    try {
      package = require.resolve(join(path, 'package.json'));
      package = JSON.parse(fs.readFileSync(package));
      path = package.browser || package.browserify || package.main;
      if (!path) {
        throw "Invalid package " + package;
      }
      return path;
    } catch (e) {

    }
  };
  module.exports = function(name, path) {
    if (!path) {
      throw 'Path required';
    }
    if (isAbsolute(path)) {
      return [namify(path), require.resolve(path)];
    } else if (isRelative(path)) {
      name = dirname(name);
      return [namify(join(name, path)), require.resolve(join(resolve(name), path))];
    } else if (isPackage(path)) {
      return [path, require.resolve(join(path, getPackagePath(path)))];
    } else {
      return [path.split('/')[0], require.resolve(path)];
    }
  };
}).call(this);
