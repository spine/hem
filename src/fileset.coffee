glob  = require('globule')
Utils = require('./utils')

# ------- Public FileSet Class

class FileSet

  constructor: (app, name, options) ->
    # set default values
    # options.commonjs ?= app.defaults.commonjs if app.defaults.commonjs?
    # options.npm      ?= app.defaults.npm if app.defaults.npm?

    # set values
    @name   = name
    @type   = options.type
    @target = options.target if options.target
    @paths  = []
 
    # TODO: make sure type is set! or get type value from target extension?

    # create paths
    for path in Utils.toArray(options.paths)
      @paths.push new Path(app, path)

  walk: ->
    files = []
    files.push.apply(files,path.walk()) for path in @paths
    files

# ------- Private Path Class

class Path

  constructor: (app, options) ->
    # first check to see if options is string or object
    if typeof options is "string"
      if options.match /[*]/
        options =
          srcBase: ""
          src: options
      else
        # default to globbing everything under a folder name
        options =
          srcBase: options
          src: "**"
    
    # set values
    @src      = options.src
    @srcBase  = app.applyRoot(options.srcBase or "")
    @commonjs = options.commonjs if options.commonjs
    @npm      = options.npm if options.npm

  walk: ->
    glob.find
      src        : @src
      srcBase    : @srcBase
      prefixBase : true # make sure we always include the srcBase in returned files

module.exports = FileSet
