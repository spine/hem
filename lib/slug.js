(function() {
  var Slug, connect, fs, hem, uglify;
  connect = require('connect');
  fs = require('fs');
  uglify = require('uglify-js');
  hem = require('./hem');
  Slug = (function() {
    function Slug() {}
    Slug.readSlug = function(path) {
      return JSON.parse(fs.writeFileSync(path || './slug.json'));
    };
    Slug.server = function(options) {
      var port, server;
      if (options == null) {
        options = {};
      }
      server = connect.createServer();
      server.use(connect.static(options.public || './public'));
      server.get('/application.js', this.package(options).createServer());
      port = process.env.PORT || options.port || 9294;
      server.serve(port);
      return port;
    };
    Slug.build = function(options) {
      var applicationPath, slug;
      if (options == null) {
        options = {};
      }
      slug = this.package(options).compile();
      slug = uglify(slug);
      applicationPath = (options.public || './public') + '/application.js';
      return fs.writeFileSync(applicationPath, slug);
    };
    Slug.static = function(options) {
      var port, server;
      if (options == null) {
        options = {};
      }
      server = connect.createServer();
      server.use(connect.static(options.public || './public'));
      port = process.env.PORT || options.port || 9294;
      server.serve(port);
      return port;
    };
    Slug.package = function(options) {
      if (options == null) {
        options = {};
      }
      return hem.createPackage({
        require: options.main || './app/index',
        libs: options.libs || './lib'
      });
    };
    return Slug;
  })();
  module.exports = Slug;
}).call(this);
