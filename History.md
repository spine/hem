
n.n.n / 2014-01-29 
==================

 * in middle of refactoring
 * big time refactoring going on...
 * fix command line argument switch
 * updating jade compiler to work with both old/new jade compile api
 * updated package #
 * fixing host command line option
 * bid spolling
 * making it possible to bind to all ips
 * getting karma close to working and tweaking some of the hem default configurations.
 * adding some compile caching to hem in server/watch mode
 * print error instead of throwing an exception
 * making tests work in watch mode using events and async library
 * updated js files and version bump
 * tweaks to testing configuration and some notes/comments on additional testing features.
 * have hem work with both json and modules.export.config
 * adding event that returns the connect app used by the server
 * making events its own module and adding watch event
 * setting incorrect home variable
 * better error message
 * ok, try this one more time, should hopefully fix the issues.
 * updated readme
 * setting up custom() method option for slug files that an instance of hem is passed into to allow customization
 * fix issue with log require in versioning module
 * making phantom an optionalDependency, if not present then open test file in browser
 * handle timeout conditions with a little more grace
 * more tweaks to the phantom test runner, still need to get multiple tests running at once...
 * tweaks to phantom test runner to allow different reporting styles
 * use all apps when finding test dependencies as sometimes there may only be one target
 * incorporate phantom runner into hem project
 * new compiled js files
 * updates assets for jasmine, eventually will have a file that lists the order the jasmine files should be loaded in.
 * updates to generate the test runner index.html file with correct paths
 * helper method to copy files
 * moving stitch commonjs file to assets as a template to load
 * using fs-extra for directory/file functions
 * adding jasmine files as assets that can be used to run tests
 * adding micro template compiler so we can store html files in assets
 * using commonjs instead of identifier part 2
 * using commonjs as config value instead of identifier
 * beginnings of event system, will expand at a later date.
 * updated version, everything should be working at this point. On to more features….
 * compiled js files
 * lots of refactoring on the server/hem/package classes, opening door for other features...
 * using 'src' instead of path, seems like a better name
 * lots of refactoring going on
 * using log module
 * using logs module
 * learn to spall, I mean spell
 * updated package dependencies to latest versions
 * using logging module
 * move logging to its own module
 * have hem look for local copy and then global.
 * better compile error handling for eco/jeco templates
 * fixed issue with uglify, wasn't getting the minified string correctly.
 * updated with better compiler errors
 * fixed issue with minifyjs not being called correctly
 * only have jade debug during server mode
 * removing the stitch eco template file
 * goodbye eco
 * some additional comments
 * ok, still need eco for the time being but will remove it soon
 * bump version
 * removing most precompilers from hem, install locally
 * removing less
 * first take at loading local modules for the compiling
 * additional tweaks to hem watch service
 * fixed some issues with the hem watch feature
 * simplify code
 * make sure we only look at files we can actuall require/compile
 * bump version
 * redoing the css compile to work with dirs and individual files
 * needed to compile js
 * used wrong function call for uglifycss
 * adding less to css compilers
 * user uglifycss to minify css
 * little bit cleaner error output
 * make sure we only watch directories
 * removing compress option from stylus compiler, will compress at end of css compile
 * updated packages to latest/greatest
 * leaving host blank as default so it will bind to both localhost and ip address
 * compiled js and version bump
 * fixing way the default port/host are handled
 * not sure how that stuff got committed, perhaps a sign of sleep deprivation??
 * minor bug fixes and refactorings from master branch
 * more colors
 * make sure missing parent directories are created.
 * fixed issue with directories not redirecting with /
 * versioning can handle different paths inside file
 * get rid of debugging statements
 * I have a good feeling about this one
 * sigh..
 * I think this should be the final windows change, famous last words..
 * I am starting to really dislike windows
 * guess I can't do x.x.x.x versions
 * debuggin windows issues
 * need compiled js file
 * platform is function call
 * some versioning refactoring, still not completely sold on approach yet...
 * trying to deal with window paths
 * updated readme
 * updated readme
 * updated readme
 * updated readme
 * updated readme
 * need to improve compile libs so that it only looks at compilable files
 * handling the @after attribute a bit differently, allow array of strings
 * building and server seem to be functional again
 * lots and lots and lots of changes, trying to get hem easier to configure, but at the same time allow a lot of customization
 * starting refactoring of testing options
 * make write to file system the default value for builds
 * make sure to write builds to file system during watch
 * some minor changes to the way files are watched
 * only minify/compress by switch, faster execution during development if turned off
 * removing debug, just need info/verbose, also ability to turn off console colors
 * versioning is working again, double yay
 * some refactoring of server flow
 * server works again, yay!
 * more refactoring fun, seems to be building correctly again
 * more refactoring
 * fixing coffee typo
 * some more major refactoring, but work still to be done
 * refactoring the server code out of the hem.coffee and into its own file. Also making it possible to use hem functions as middleware in a connect/express server.
 * default patchRedirect to true
 * updated package information and dependencies
 * Merge remote-tracking branch 'origin/master' into version0_3
 * adding package.json version output to help command
 * updating to 0.3.6
 * compiled javascript files
 * versioning tweaks
 * updated http-proxy module doesn't supply headers as a parameter to writeHead anymore
 * update to version number and updated dependencies
 * new javascript compile
 * new compilers module, inspired by http://blog.divshot.com/post/31336785156/exposing-env-to-spine
 * read from relative directory
 * setting variables in compilers module
 * removing some extra console logs
 * compiled javascript
 * some refactoring to get a first try at file versioning in. Also moved some of server code out of the package.coffee file.
 * few updates to hem readme
 * merge version0_3 into master branch with theirs stategy
 * ok, its really working this time. Had to use a RexExp object to replace to work as intended
 * better redirect patch, less picky if the port number is there or not
 * new javascript compiled files
 * better error handling for coffee script compile errors
 * updated testacular to karma
 * bumping package version
 * updating package json to get latest testacular and stylus
 * ok building the javascript files one more time, using latest coffee script
 * Merge branch 'version0_3' of github.com:spine/hem into version0_3
 * updated javascript files from coffee script 1.6.1 build
 * updating jade
 * Fix for .litcoffee compilation
 * litcoffee actually work? - bump version
 * Merge pull request #66 from jamiter/master
 * Fix for .litcoffee compilation
 * build all with latests coffee
 * Added .litcoffee support (CoffeeScript 1.5.0)
 * compile w coffeescript 1.5.0, and bump version
 * Merge pull request #65 from jamiter/master
 * Added .litcoffee support (CoffeeScript 1.5.0)
 * line numbers in generated css is not easy to do with hem. :(
 * optional css compile for hem server, still figuring out for watch.
 * Merge branch 'master' of github.com:spine/hem
 * minor code cleanup and recompile w coffeescript 1.4.0
 * Make sure both the path and indexed path are used to see if a module already exists in the cache. Fixes #62
 * Merge branch 'master' of github.com:spine/hem
 * Make sure both the path and indexed path are used to see if a module already exists in the cache. Fixes #62
 * Merge branch 'version0_3' of github.com:spine/hem into version0_3
 * trrying to resolve mergeHead existing...
 * updated javascript files
 * use not instead of unless
 * merging some doc changes from master
 * bad syntax in readme
 * strata requires newer node.js therefor so does hem.
 * small updates to readme
 * Merge branch 'version0_2' of github.com:globalvetlink/hem into version0_2
 * small fix in docs for using --host arg from command line
 * Merge branch 'using_connect_instead_of_strata' into version0_3
 * Merge branch 'using_connect_instead_of_strata' of github.com:globalvetlink/hem into using_connect_instead_of_strata
 * work on documenting some of the slug.json settings changes that are different in 0.3
 * v for verbose
 * just getting some repo references straight
 * just getting some repo references straight
 * tested the optional compress setting, and compiled
 * include css is optional with param 'hem server --includeCss'
 * conditional stylus include css option 'hem server --includeCss', and default compression of css unless in debug mode
 * default will compress the css. to get uncompressed use debug mode
 * fixing readme typos - add jqery templates removal note
 * small refinements to readme prep for version 2 release
 * seem to be missing a ) in the statement
 * Merge branch 'using_connect_instead_of_strata' of github.com:globalvetlink/hem into using_connect_instead_of_strata
 * removing the spawn option idea, keep hem simple
 * Merge branch 'using_connect_instead_of_strata' of github.com:globalvetlink/hem into using_connect_instead_of_strata
 * updated javascript files
 * bringing over new proxy redirect logic for handling changes in port number. Using 'patchRedirect' will keep all redirect responses on the same port as the hem server.
 * resolve hanging cherry-pick weirdness in git
 * cherry-pick some stylus debug options from strata based branch
 * adding some debug options to stylus compiler, don't seem to be working yet, but not breaking either.
 * hopefully the final fix to get linked modules working with hem, adding any new directories that appear to be valid to the modulePaths array for future use. Should help when modules use require to include additional files.
 * hopefully the final fix to get linked modules working with hem, adding any new directories that appear to be valid to the modulePaths array for future use. Should help when modules use require to include additional files.
 * Merge branch 'master' of github.com:globalvetlink/hem into master_globalvetlink
 * experimental fix for working with linked modules. Seems like module._findPath always returns the real path if the module is linked so there really insn't any way to tell if it is a linked module, just use the path given? Hopefully this works.
 * small updates to readme preparing for release to master branch and thus npm
 * planning out the feature of adding file versioning for long caching at build time
 * bringing in npm description stuff from version 3 branch
 * few tweak to package json including a version bump
 * lets bump that version#!
 * Merge branch 'master' of github.com:globalvetlink/hem into master_globalvetlink
 * apply updated javascript that is used by stitch. It includes fixes to help with circular requires. At some point probably should just include stitch as a node module.
 * small tweak to package json, >= prefers latest when do npm install .
 * updated stitch generate javascript, includes fixes to help with circular requires.
 * updating package version and repo string
 * experimental support for linked node_modules, not fully tested but seems to work at least on mac/unix
 * fixing windows issue, need to make sure we take care of all of the slashes that could potentially be in the id variable
 * error handling improved, better messages
 * ok, really fixing for windows this time. needed to apply the replace as a global regex, otherwise will just perform once.
 * return real Error objects on errors
 * making the package class a little more reusable, also printing error object stack value if available.
 * don't assume that @options.routes is always set
 * fixed passing debug flag to middleware compilation
 * fixing broken watch method in package.coffee
 * fix that should allow hem to build with the correct require name on windows systems
 * hopefully these fixes makes everything compatible when running on windows, before the module.id was was including the entire path.
 * updated js files
 * tweaks to console output
 * adding noBuild option for only serving static files.
 * no longer used since testacular handles running jasmine tests
 * setting compilers.DEBUG variable from argv.debug value, this way we don't have to keep looking at process.argv in the compilers module
 * latest javascript compiled files (with coffee script 1.4)
 * using variable name identifier instead of require for the stitch namespace option, if undefined it should resort to "require"
 * forgot to pass in argv to the Package constructor
 * setup verbose mode for some console.log statements
 * better variables names and using argv value passed in to perform optional steps
 * better argv handling and descriptions
 * Merge branch 'master' into using_connect_instead_of_strata
 * few small updates to readme
 * think this fixes some unitended lieniency in depencies.
 * opps, impropperly formatted the contributors value
 * few tweaks to the package.json
 * experimental, allow an @options.server.spawn option to be set in slug.json to kick off another process. For example to launch the grails app the following json could be used     "spawn" : {       "command" : "grails",       "args"    : ["run-app"],       "options" : { "cwd":"../segway", "stdio": "inherit" }     }
 * allow browsers command line argument to list multiple browsers
 * no longer using the css.coffee/js module
 * updated to coffee script 1.4
 * big time commit, lots of changes for the package system, with the goal of having a lot of flexibility to have multiple javascript and css targets
 * updated proxy/server portion to use values from the options variable. Next step is to bring in all the package changes...
 * provide a way to call clean
 * make slug.json an optional parameter
 * working version of hem with connect, but has hardcoded values, will need to change that in next commit
 * Merge branch 'master' of github.com:globalvetlink/hem into master_globalvetlink
 * quick hack to only build the package that had the change (specs or hem), will improve on this later when committing the changes related to the improved packages support
 * updated to testacular version 0.4
 * just updating some github link references
 * tweaks to error message.
 * better error handling for jade compiles
 * Merge branch 'master' of github.com:globalvetlink/hem into master_globalvetlink
 * adding try/catch to compile step
 * Merge branch 'master' of github.com:globalvetlink/hem
 * first draft of testing documentation in the readme
 * need to add the require('lib/setup') at the end of the specs.js file to pickup all of the javascript modules that spine ends up using.
 * Merge branch 'jade' of github.com:aeischeid/hem into jade
 * pretty sure the 'forward' options weren't actaully doing anything important for the proxy, little cleanup around that
 * trying a slightly different approach to proxy, works the same
 * just a little cleanup in the jade section of the compilers file
 * updates to the readme file, including todo section
 * updating readme with some instructions on using jade templates
 * working jade templates (must use jades runtime.js in spine project) - small templates cut size about in half by using jade over eco
 * merging testacular into dust (which should be jade) branch
 * lets run testacular on 9090 to avoid conflicts if using tomcat/javaish servers for api
 * opps, was creating new regex object for each request in proxy mode. added console message if using proxy.
 * compiled new hem.js
 * merging testacuar approach with master, branching off for now
 * update version to 0.2.4
 * Merge branch 'master' of git://github.com/cengebretson/hem
 * using fs instead of path for existsSync
 * working on documenting usage of optional proxy
 * built, and updated readme.
 * merging master
 * merging in changes from cengebretson
 * Merge pull request #3 from doublerebel/patch-3
 * Merge pull request #1 from doublerebel/patch-1
 * Merge pull request #2 from doublerebel/patch-2
 * removing test strata mapping
 * add option to build test file specs.js and also provide an option to watch if any file changes to to specs source files
 * updated all node libraries to latest versions
 * redoing how tests are served up by strata
 * use fs instead of path
 * One more lingering path.existsSync
 * Bump strata version for node 0.8 compatibility
 * Change git url to git:// for npm compatibility
 * added watch
 * actual working regex for the proxying magic
 * psuedo code for the regex base path stuff. comments explaining thoughts behind proxy
 * well it at least compiles
 * wild untested stab at proxy layer
 * bringing in .jeco enhancement - object includes index prop, and optionaly extra data
 * sync with maccman/master
 * bring in customizable host config from https://github.com/mmavko/hem/commit/0f382b1ca66e66ff379f9bd6815d754b0d0bf222
 * lingering fs > path update for updated node API
 * version bumps required for npm to pull in updates. makes sense
 * compiled
 * updated uglify dependency
 * adding a todo in the readme for adding proxy capabilities to hem
 * Merge pull request #55 from kapadia/master
 * first stab at porting old spinejs.com hem docs into hem readme file
 * just some little changes to go with the idea of this branch being the new hem source in npm. nothing official yet
 * updating some dependencies in the package.json (stylus, optimist, fast-detective, coffee-script)
 * porting in dust templates and simple html string templates from : https://github.com/guillaume86/hem/commit/6977b1aecf6955aed96cc1bc7727638e76eac4df
 * adding a few todo's in the readme, and reference for direct install vai github
 * GET to application.js and css using unminified versions
 * Updated uglify
 * updated readme and source with some ideas and todos
 * changing path.existsSync to fs.existsSync (to get rid of warning message)
 * update stylus version
 * Using strata.map() to force the strata server to always generate/compile the application.js and application.css from the source files.
 * Merge branch 'master' of github.com:maccman/hem
 * fix /test/specs.js
 * Merge pull request #45 from stephenvisser/patch-1
 * Remove redundant stylus dependency
