# Introduction

Hem is a project for compiling CommonJS modules when building JavaScript web applications. You can think of Hem as [Bundler](http://gembundler.com/) for Node, or [Stitch](https://github.com/sstephenson/stitch) on steroids. Or it is kind of like [Yeoman](http://yeoman.io/), tailored specifically for spine.js

This is rather awesome, as it means you don't need to faff around with coping around JavaScript files. jQuery can be a npm dependency, so can jQueryUI and all your custom components. Hem will resolve dependencies dynamically, bundling them together into one file to be served up. Upon deployment, you can serialize your application to disk and serve it statically.

Hem was primarily designed for developing Spine.js based Single Page Web Applications (SPA's), so a major role it fills is to tie up some of the other lose ends of a frontend development project - things like running tests, precompiling code, and preparing it for deployment. It can even help out in the API connection stuff if your app needs that.

# Installation

    npm install -g hem

or

    npm install -g git://github.com/spine/hem.git

or ...fun trick.

    git clone https://github.com/spine/hem.git
    cd hem
    npm link

the last approach is great if you want to customize hem for your own use, (...or for developing npm packages in general). Just fork and use you own path!

## Dependencies

Hem has two types of dependency resolutions: Node modules and Stitch modules.

**Node modules**: Hem will recursively resolve any external Node modules your code references. This means that Spine, jQuery etc, can all be external Node modules - you don't have lots of libraries floating around your application. This also has the advantage of explicit versioning; you'll have much more control over external libraries.

**Stitch modules**: Hem will bundle up your whole application (without any static dependency analysis), automatically converting CoffeeScript (.coffee) and jQuery template (.tmpl) files. Hem doesn't use static analysis of your application to determine dependencies, as that's often not-viable considering the amount of dynamically loaded dependencies most applications use.

In a nutshell, Hem will make sure your application and all its dependencies are wrapped up in a single file, ready to be served to web browsers.

## CommonJS

CommonJS modules are at the core of Hem, and are the format Hem aspects every module to adhere to. As well as ensuring your code is encapsulated and modular, CommonJS modules give you dependency management, scope isolation, and namespacing. They should be used in any JavaScript application that spans more than a few files.

To find out more about why CommonJS modules are a great solution to JavaScript dependency management, see the CommonJS guide. It's not that AMD pattern is bad by the way, just not the way hem went for now.

### Example CommonJS

The format is remarkably straightforward, but is something you'll have to adhere to in every file to make it work. CommonJS uses explicit exporting; so to expose a property inside a module to other modules, you'll need to do something like this:

In app/controllers/users.coffee:

    class Users extends Spine.Controller

Explicitly export the Users object

    module.exports = Users

The format mandates that a module object will be available in every module. However, if you're targeting both the CommonJS format, and a normal environment, you can do a conditional export, checking that the module object exists.

    module?.exports = Users

### Requiring modules

Requiring other modules is just as straightforward; just use the require() function.

    Users = require("controllers/users")

In Hem apps, all module paths are relative to the app folder - so don't require files relative to the specific module.
CSS

## Styling your app

Hem will also bundle up all your application's CSS into one file, ready to serve up to clients. CSS encapsulation and modularity is just as important as JavaScript de-coupling (and can get as equally messy if it's not done right); Hem goes some way to help you with this. To compile CSS, Hem uses an excellent library called Stylus. Stylus is mostly a superset of CSS, and the normal CSS syntax will work just fine if that's all you want.

However the awesome part of Stylus is the extra syntactical sugar it brings to CSS. Features like optional braces and colons, mixins, variables and significant whitespace all vastly improve your application's CSS, and decreases the amount of typing necessary. In a nutshell, Stylus is to CSS as CoffeeScript is to JavaScript.

Stylus files are indicated by the .styl extension, and are automatically compiled down to CSS by Hem. This all happens in the background, so you don't need to worry about it.

Also in the pipeline is the ability to bundle up CSS from Node modules.

## Configuration

Hem has some good defaults (convention over configuration), but sometimes you'll need to change them, especially when adding libraries and dependencies.

For configuration, Hem uses a `slug.coffee` file, located in the root of your application. Using coffee syntax allows you to dynamically construct the final configuration object. An example configuration is show below...

```
config =

    # hem server and test settings
	hem:
        baseAppRoute: "/"
        tests:
            runner: "browser"

    # application settings
	application:
		defaults: "spine"
        css:
            src: 'css'
		js:
            src: 'app'
			libs: [
				'lib/jquery.js',
				'lib/jade_runtime.js'
			]
			modules: [
				"spine",
				"spine/lib/ajax",
				"spine/lib/route",
				"spine/lib/manager",
				"spine/lib/local"
			]
		test:
			after: "require('lib/setup')"

# export the configuration map for hem
module.exports.config = config
```

By setting the `defaults` value to `spine` Hem expects a certain directory structure. A main JavaScript/CoffeeScript file under app/index, a main CSS/Stylus file under css/index and a public directory to serve static assets from. If you're using `Spine.app`, these will all be generated for you. A typical spine app will have the following folder structure

```
├── app
│   ├── controllers
│   ├── index.coffee
│   ├── lib
│   ├── models
│   └── views
├── css
│   ├── index.styl
│   └── mixin.styl
├── lib
│   ├── jade_runtime.js
│   └── jquery.js
├── node_modules
│   ├── jade
│   ├── spine
│   ├── stylus
├── package.json
├── public
│   ├── application.css
│   ├── application.js
│   ├── favicon.ico
│   └── index.html
├── slug.coffee
└── test
    ├── public
    └── specs
```

The configuration file has several sections that control how the application is built and tested. For the `hem` section the following can be provided:

* `hem.baseAppRoute` the url context from which hem will serve its files.
* `hem.tests.runner` the way tests are executed, the default value is `browser`. If you have karma installed you can use `karma` as the value to fallback on the karma test runner.
* `hem.proxy` allows you to specify proxy paths that will route requests to another server behind the scenes.

        "/proxy":
            "host": "www.yoursite.com"
            "path": "/proxy"
            "port": 8080

For the `application` settings the following can be used:

* `application.defaults` currently the only valid value is `spine`
* `application.root` the root folder of your project files, defaults to the root directory of the project folder (same folder that the slug.coffe file is found)
* `application.route` another way to append a `context` for the app when hem is serving files. The default value is `\\`. This value is appended to the `baseAppRoute` value to create the final url path to the application.
* `application.static` allows you to list the path to multiple folders for serving static content. The default `spine` values are listed below.

        "static":
            "/": "public",
            "/test": "test/public"

* `application.js.libs` the `libs` folder is where hem looks to simply append files to the final application js file. If you list just a directory then all the js/coffee files in that directory are added. If you want the files added in a specific order then you can list the files individually.

        "libs": [
            "./lib/other.js"
        ]


* `application.js.src` the `src` folder is where hem looks to find `js` files process and add to the final application css file. If you list just a directory then all the js/coffee files in that directory are added. Every file found in the `src` folder will be bundled with `CommonJS` and will need to be `required` for it to be used.

        "src": [
            "./app"
        ]

* `application.js.modules` In addition, Hem lets you specify an array of npm/Node dependencies, to be included in your application. These dependencies will be statically analyzed, to recursively resolve additional dependencies, and then wrapped in the CommonJS module format, being served up with the rest of your application's JavaScript. For example, in a default generated Spine.app slug.json file, you'll find the following dependencies:

        "modules": [
            "spine",
            "spine/lib/ajax",
            "spine/lib/route",
            "spine/lib/manager",
            "spine/lib/local"
        ]

* `application.js.target` the name of the single js file that is produced after all the src files are processed. If no value is provided the `spine` default is `public/application.js`

        "target": "public/application.js"

* `application.css.src` the `src` folder is where hem looks to find `css` files process and add to the final application css file. If you list just a directory then all the css/jade files in that directory are added. If you want the files added in a specific order then you can list the files individually.

        "src": [
            "./css/other.css"
        ]

* `application.css.target` the name of the single css file that is produced after all the src files are processed. If no value is provided the `spine` default is `public/application.css`

        "target": "public/application.css"

* `application.test` allows you to define which files are used for testing. This has similar settings as the `js` section of the application with the `src` and `target` fields. In addition there is the `commonjs` field that allows you to name the wrapper which is used to contain the modules. In this case you would use `specs('someControllerTest')` to require the test file. Also the `after` field allows you to append any javascript that needs to be executed to make sure your tests will run correctly.

        "test":
            "commonjs": "specs",
            "src": [
                "test/specs"
            ],
            "target": "test/public/specs.js"
            "after": "require('lib/setup')"


## Usage

Ok, so now we've looked at how to configure Hem, let's actually use it in an application. As I mentioned earlier, this step is much easier with an application previously generated by Spine.app, and I advise you go down this route if you're unfamiliar with Hem.

Now, we can start a development server, which will dynamically build our application every request, using the server command:

    hem server

By default, your spine application is served at http://localhost:9294.
You can configure the host and port from command line or as settings in your package.json

    hem server -p 9295

Would result in your application being served at http://localhost:9295/

If there's an index.html file under public, it'll be served up. Likewise, any calls to /application.js and /application.css will return the relevant JavaScript and CSS.

When you're ready to deploy, you should build your application, serializing it to disk.

    hem build

This will write application.js and application.css and specs.js to the file system. You can then commit it with version control and have your server can statically serve your application, without having to use Node, or have any npm dependencies installed.


### Views

Currently Hem supports three template options out of the box
* Basic HTML - stringifed html... that you can render...
* [Eco](https://github.com/sstephenson/eco) - erb like syntax, like ejs, but with coffeeScript. Nice, but seems to be a somewhat abandoned project
* [Jade](https://github.com/visionmedia/jade) - haml like syntax with optional coffeescript filter
  * to use jade templates you must include jades [runtime.js](https://github.com/visionmedia/jade/blob/master/runtime.js) as a lib in your spine projects slug.json
      "libs": ["lib/runtime.js"],

### Testing

[Karma(formally Testacular)](http://karma-runner.github.io/0.8/index.html) is a neat little tool that we leverage with hem.

    hem test

Will run tests in a spine projects test directory. Tests can be written in CoffeeScript!

    hem watch -t

Will run tests as test files are updated. Karma makes it smart. Only previously failing tests run. If there were no previously failing tests all will run.
Default is to run tests in a new Chrome window. Firefox, Phantom or some others can be used as well.

    hem server

will watch and compile jasmine tests, but you will have to go to localhost:9294/test (or where ever you configured hem to run...) and manually trigger page tests to run.
