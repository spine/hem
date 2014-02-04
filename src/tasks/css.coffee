uglifycss = require('uglifycss')
path      = require('path')
fs        = require('fs')
uglifycss = require('uglifycss')
utils     = require('../utils')

# ---------- helper function to perform compiles

requireCss = (filepath) ->
  filepath = require.resolve(path.resolve(filepath))
  delete require.cache[filepath]
  require(filepath)

# ---------- define task

task = ->
  @targetExt = "css"
  @bundle    = true

  # main task to compile and minify css
  return (params) ->
    try
      output = []
      # TODO: use glob to get set of files...
      # TODO: eventually make similar setup to js compile so we only accept
      #       the file that changes and cache the others...
      for fileOrDir in @src
        # if directory loop over all top level files only
        if utils.isDirectory(fileOrDir)
          for file in fs.readdirSync(fileOrDir) when require.extensions[path.extname(file)]
            file = path.resolve(fileOrDir, file)
            output.push requireCss(file)
        else
          output.push requireCss(fileOrDir)

      # join and minify
      result = output.join("\n")
      result = uglifycss.processString(result) if @argv.compress
      result
    catch ex
      @handleError(ex)
      return ""

module.exports = task
