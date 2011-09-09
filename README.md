#Introduction

Hem is a project for compiling CommonJS modules when building JavaScript web applications. You can think of Hem as [Bundler](http://gembundler.com/) for Node, or [Stitch](https://github.com/sstephenson/stitch) on steroids. 

This is rather awesome, as it means you don't need to faff around with coping around JavaScript files. jQuery can be a npm dependency, so can jQueryUI and all your custom components. Hem will resolve dependencies dynamically, bundling them together into one file to be served up. Upon deployment, you can serialize your application to disk and serve it statically. 

#Installation

    npm install -g hem

#Commands

<!-- * `hem new`    - generate new project -->
* `hem server` - host slug server (for development)
* `hem static` - host static slug server (for production)
* `hem build`  - build and minimize application in ./public dir

Slug would be in charge of collecting all third-party dependencies (listed in slug.json) and injecting them as CommonJS modules / CSS / assets.

When it comes to deployment you'd do:

    hem build
    git add ./public
    git commit -m 'version x'
    git push heroku master

Or if you were building a PhoneGap application:

    hem build
    phonegap --ios ./public

#Slug.json

Slugs are how Hem knows about application. Think of them as a bit like Gemfiles. 
    
    {
      // Specify main JavaScript file:
      "main": "./app/index",
      
      // Specify main CSS file:
      "css": "./css/index.less",
      
      // Specify public directory:
      "public": "./public",
      
      // Add load paths:
      "paths": ["./app"],
      
      // We want these to load before (not CommonJS libs):
      "libs": [
        "./lib/other.js"
      ]
    }
    