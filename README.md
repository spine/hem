Experimental Hem (aka version 4)
================

This branch of hem is an experimental refactoring of the current hem code base. The changes in this branch are born from trying to get the current hem
to work with multiple frontend apps that shared a common code base but at the same time were sepearate web apps. 

Initially we had used multiple
hem/spine projects for each frontend and git sub-tree to share the common code, but even that seems tedius. The goal going forward is to be able to
have multiple applications definied with the slug.json and have the ability to be able to build/server/test them all together or on a per app basis. 
This allows us to generate a common.js file that contains the main spine/jquery javascript which then can be included in each project's html file.

In addition, the current version of hem needs a bit of setup/configuration in the slug.json file. I am hoping that if a user follows certain 
conventions and folder structures the amount of configuration should be minimal. The current spine structure seems to be...

```
spineapp
  - app          // js/coffee files that are stitched together using commonjs
  - public       // static files and final app js/css build destination
  - lib          // plain old js/coffee files appended to js file.
  - node_modules // node modules to include
  - test         // test/spec files 
  - css          // css and stylus files to compile
```

By using the above structure, everything should be hooked up and ready to go from hem's point of view. But I also want to allow the ability to 
easily override this struture, perhaps for cases when somebody is creating a non-spine web app and just wants to make use of the compiler/server.

Other goals and features...
----

In addition to the above ideas, I want to try to get some of the features below integrated into hem...

- [*] Easier to setup proxy
- [*] ability to act as middleware for connect/express apps
- [*] versioning abilities
- [ ] easier testing setup and execution (karma/phantomjs)
- [ ] Simple event system
- [ ] livereload abilities for css and possibly js
- [ ] manifest creation
- [ ] update examples/documention
- [ ] really do need to write some tests for hem

Will look into but not 100% sure
---

These would be nice to have things, will have to research it more in the future...

- [*] easier ways to add your own compilers/extensions
- [ ] source mapping
- [ ] integrate spine.app commands into hem
- [ ] possibly look at AMD vs commonjs???
- [ ] jshint/lint checks??

When will it be done??
---

Thats a good question :) I think its possible to have the main features done, tested, and ready to go by the end of november :o).

