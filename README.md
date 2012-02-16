#Introduction

Hem is a project for compiling CommonJS modules when building JavaScript web applications. You can think of Hem as [Bundler](http://gembundler.com/) for Node, or [Stitch](https://github.com/sstephenson/stitch) on steroids. 

This is rather awesome, as it means you don't need to faff around with coping around JavaScript files. jQuery can be a npm dependency, so can jQueryUI and all your custom components. Hem will resolve dependencies dynamically, bundling them together into one file to be served up. Upon deployment, you can serialize your application to disk and serve it statically. 

#Installation

    npm install -g hem

#Usage

Please see the [Hem guide](http://spinejs.com/docs/hem) for usage instructions.

#Additional Support for Server Side

The "hem server" command will now look for a "serverSlug.json" file (file path is a property in the slug.json package called "serverSlug".) It will watch all files within the "serverSlug.json".paths property and make sure they are always up to date and get reloaded when the developer changes any files within these paths. The first path is assumed to be the server code. The exports of the server code need to be as follows:

function initOnce(strata.Builder) called once during server startup. Even during reload this will not get called again. The idea is that it can be used to add mime types or loggers and the like to the strata.Builder.

<code>
strata = require 'strata'
 
router = new strata.Router
 
exports.router = router
 
router.get '/item', (env, callback) ->
  callback 200, {}, '{"name":"Somebody", "email": "somebody@example.com"}'
 
exports.initOnce = (app) ->
  app.use strata.commonLogger
  app.use strata.contentType, 'text/html'
  app.use strata.contentLength
</code>

This allows server code to automatically reload when the developer changes it.