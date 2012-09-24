#Introduction

Hem is a project for compiling CommonJS modules when building JavaScript web applications. You can think of Hem as [Bundler](http://gembundler.com/) for Node, or [Stitch](https://github.com/sstephenson/stitch) on steroids.

This is rather awesome, as it means you don't need to faff around with coping around JavaScript files. jQuery can be a npm dependency, so can jQueryUI and all your custom components. Hem will resolve dependencies dynamically, bundling them together into one file to be served up. Upon deployment, you can serialize your application to disk and serve it statically.

#Installation

    npm install -g hem

or

    npm install -g git://github.com/aeischeid/hem.git

or ...fun trick I just learned

    hem install -g hem 
    git clone https://github.com/aeischeid/hem.git
    cd hem
    npm link

this last approach is great if you want to customize hem for your own use, or for developing npm packages in general

##Dependencies

Hem has two types of dependency resolutions: Node modules and Stitch modules.

Node modules: Hem will recursively resolve any external Node modules your code references. This means that Spine, jQuery etc, can all be external Node modules - you don't have lots of libraries floating around your application. This also has the advantage of explicit versioning; you'll have much more control over external libraries.

Stitch modules: Hem will bundle up your whole application (without any static dependency analysis), automatically converting CoffeeScript (.coffee) and jQuery template (.tmpl) files. Hem doesn't use static analysis of your application to determine dependencies, as that's often not-viable considering the amount of dynamically loaded dependencies most applications use.

In a nutshell, Hem will make sure your application and all its dependencies are wrapped up in a single file, ready to be served to web browsers.

**TODO**: figure out a way to have common depenencies share easily between multiple spine apps. 
for example. jqery, es5-shim, or certain js-plugins shouldn't have to be wrapped inside of 3 different application.js files if you have three spine apps served at the same domain. you probably would have shared css, images, and maybe even some share spine models and controllers. 

##CommonJS

CommonJS modules are at the core of Hem, and are the format Hem aspects every module to adhere to. As well as ensuring your code is encapsulated and modular, CommonJS modules give you dependency management, scope isolation, and namespacing. They should be used in any JavaScript application that spans more than a few files.

To find out more about why CommonJS modules are the best solution to JavaScript dependency management, see the CommonJS guide
The format

The format is remarkably straightforward, but is something you'll have to adhere to in every file to make it work. CommonJS uses explicit exporting; so to expose a property inside a module to other modules, you'll need to do something like this:

  # In app/controllers/users.coffee:
    class Users extends Spine.Controller

  # Explicitly export the Users object
    module.exports = Users

The format mandates that a module object will be available in every module. However, if you're targeting both the CommonJS format, and a normal environment, you can do a conditional export, checking that the module object exists.

    module?.exports = Users

##Requiring modules

Requiring other modules is just as straightforward; just use the require() function.

    Users = require("controllers/users")

In Hem apps, all module paths are relative to the app folder - so don't require files relative to the specific module.
CSS

Hem will also bundle up all your application's CSS into one file, ready to serve up to clients. CSS encapsulation and modularity is just as important as JavaScript de-coupling (and can get as equally messy if it's not done right); Hem goes some way to help you with this. To compile CSS, Hem uses an excellent library called Stylus. Stylus is mostly a superset of CSS, and the normal CSS syntax will work just fine if that's all you want.

However the awesome part of Stylus is the extra syntactical sugar it brings to CSS. Features like optional braces and colons, mixins, variables and significant whitespace all vastly improve your application's CSS, and decreases the amount of typing necessary. In a nutshell, Stylus is to CSS as CoffeeScript is to JavaScript.

Stylus files are indicated by the .styl extension, and are automatically compiled down to CSS by Hem. This all happens in the background, so you don't need to worry about it.

Also in the pipeline is the ability to bundle up CSS from Node modules.

##slug.json

Hem has some good defaults (convention over configuration), but sometimes you'll need to change them, especially when adding libraries and dependencies.

For configuration, Hem use a slug.json file, located in the root of your application. Hem expects a certain directory structure. A main JavaScript/CoffeeScript file under app/index, a main CSS/Stylus file under css/index and a public directory to serve static assets from. If you're using Spine.app, these will all be generated for you.

Hem also allows you to specify static JavaScript libraries to include, under the "libs" option:

    {
      "libs": [
        "./lib/other.js"
      ]
    }

These will be included before the rest of your JavaScript, and without being wrapped in the CommonJS module transport format. In addition, Hem lets you specify an array of npm/Node dependencies, to be included in your application. For example, in a default generated Spine.app slug.json file, you'll find the following dependencies:

    {
      "dependencies": [
        "es5-shimify",
        "json2ify",
        "jqueryify",
        "jquery.tmpl",
        "spine"
      ]
    }

These dependencies will be statically analyzed, to recursively resolve additional dependencies, and then wrapped in the CommonJS module format, being served up with the rest of your application's JavaScript. In other words, you don't have to have jquery.js, spine.js and json2.js floating around inside your application, they can be Node modules, installed through npm.

##Usage

Ok, so now we've looked at how to configure Hem, let's actually use it in an application. As I mentioned earlier, this step is much easier with an application previously generated by Spine.app, and I advise you go down this route if you're unfamiliar with Hem.

Now, we can start a development server, which will dynamically build our application every request, using the server command:

    hem server

By default, your spine application is served at http://localhost:9294. 
You can configure the host and port from command line or as settings in your package.json

    hem server -p 9295 -host 192.168.1.1
    
Would result in your application being served at http://192.168.1.1:9295/

If there's an index.html file under public, it'll be served up. Likewise, any calls to /application.js and /application.css will return the relevant JavaScript and CSS.

For the sake of avoiding cross domain issues in development environments when your spine app is utilizing an ajax api there is a optional proxy server built into hem.
Including the following in your slug.json configures that:

    "useProxy": true,
    "baseSpinePath": "/apiapp/spineapp/",
    "baseApiPath": "/apiapp/",
    "apiHost": "localhost",
    "apiPort": 8080,
    "proxyPort": 8001,

now http://localhost:8001/apiapp/spineapp/ will return the spine app.

and http://localhost:8001/apiapp/ will return your apiApp

so relative links like @url = "../api/album/" from inside your spine app can resolve against your apiapp without issue

When you're ready to deploy, you should build your application, serializing it to disk.

    hem build

This will ensure that your server can statically serve your application, without having to use Node, or have any npm dependencies installed.

**TODO**: hem build should have an option to version the js/css it producess and replace the references in index.html as well

    hem build -v
    
###Views

Currently Hem supports three template options out of the box 
* Straigt HTML - stringifed html... that you can render... 
* [Eco](https://github.com/sstephenson/eco) - erb like syntax, like ejs, but with coffeeScript. Nice, but seems to be a somewhat abandoned project
* [Jade](https://github.com/visionmedia/jade) - haml like syntax with optional coffeescript filter
  * to use jade templates you must include jades [runtime.js](https://github.com/visionmedia/jade/blob/master/runtime.js) as a lib in your spine projects slug.json
      "libs": ["lib/runtime.js"],

#TODO

* Need to setup HEM so that it will build/compile a physical specs file (in progress)
* Integrate with [Testacular](https://github.com/aeischeid/hem/tree/testacular)
  * document usage instructions
* Check if running at root at project, look for slug.json file and throw error if its not there??
* This would be cool -> integrate with live-reload for changes. We should be able to inject [live-reload](https://github.com/livereload/livereload-js) while in server mode and then run the livereload-server inside hem or could strata handle the incoming requests? Looks like simple json requests. Would we need an option for the browser to regain its focus? Another option is instead of injecting the script into the page is to use the live reload plugin.
* Make hem more generic to work with other types of frameworks like angular?? probably move more configuration to slug.json if we do this
  * actually with more generic projects out there like [yeoman](http://yeoman.io/) maybe Hem should aim to be a dedicated spine dev tool.
* Update this readme or maybe make some github pages

#History

Originally developed by @maccman to compliment Spine.js. He started a replacement project which is a ruby based project called catapult. Some of us still love the mode.js and hem way of doing things. In the spirit of open source it is forked and we are hoping to disccus moving npm repo to point to this version of hem which we plan to maintain for the near future at least.
