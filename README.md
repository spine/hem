#Introduction

Hem is a project for compiling CommonJS modules when building JavaScript web applications. You can think of Hem as [Bundler](http://gembundler.com/) for Node, or [Stitch](https://github.com/sstephenson/stitch) on steroids. 

This is rather awesome, as it means you don't need to faff around with coping around JavaScript files. jQuery can be a npm dependency, so can jQueryUI and all your custom components. Hem will resolve dependencies dynamically, bundling them together into one file to be served up. Upon deployment, you can serialize your application to disk and serve it statically. 

#Installation

    npm install -g hem

#Usage

Please see the [Hem guide](http://spinejs.com/docs/hem) for usage instructions.

# Using compilers
People have different opinions about their preferred flavor of templating. Rather than extend
hem and carry along all the dependencies of the compilers, you can now extend hem declaritively.

1. Add the npm module that provides the hem-compiler implementation to your package.json
2. Declare the mapping of file extension to the module in slug.json
3. Write your templates in your preferred format

Known compilers:

* [hem-compiler-haml](https://github.com/deafgreatdane/hem-compiler-haml)

Sample slug.json

    {
        "dependencies": [
            "es5-shimify",
            "json2ify",
            "jqueryify",
            "spine",
            "spine/lib/local",
            "spine/lib/ajax",
            "spine/lib/route",
            "spine/lib/manager"
        ],
        "libs": [],
        "compilers":{
           "haml":"hem-compiler-haml"
        }
    }


## Writing new compilers
Each compiler is encapsulated in an npm package. This package is probably just a shim, delegating
the compilation to the actual package, but wrapping it a way that makes in friendly to hem's conventions.

The package should export a single function called "compile" that takes a single file path argument and
returns a string that represents the module definition to be used on the client.

For example, here's the extent of the definition for using haml (as encapsulated in the [hem-compiler-haml](http://github.com/deafgreatdane/hem-compiler-haml) package

    var HamlCoffee = require('haml-coffee/lib/haml-coffee');
    var CoffeeScript = require('coffee-script')
    var fs   = require('fs');

    var compile = function(path) {
      var compiler, content, template;
      compiler = new HamlCoffee({});
      content = fs.readFileSync(path, 'utf8');
      compiler.parse(content);
      template = compiler.precompile();
      template = CoffeeScript.compile(template);
      return "module.exports = (function(data){ return (function(){ return " + template + " }).call(data); })";
    };

    module.exports.compile = compile;

