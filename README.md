#Introduction

Hem is a project for compiling CommonJS modules. 

#Commands

* `hem new`    - generate new slug
* `hem server` - host slug server (for development)
* `hem static` - host static slug server (for production)
* `hem build`  - build slug in ./build dir, minimize

Slug would be in charge of collecting all third-party dependencies (listed in slug.json) and injecting them as CommonJS modules / CSS / assets.

When it comes to deployment you'd do:

    hem build
    git add ./public
    git commit -m 'version x'
    git push heroku master

Or if you were building a PhoneGap application:

    hem build
    phonegap --ios ./public