uglifycss = require('uglifycss')
path      = require('path')
utils     = require('utils')
fs        = require('fs')

# helper function to perform compiles
requireCss = (filepath) ->
  filepath = require.resolve(path.resolve(filepath))
  delete require.cache[filepath]
  require(filepath)

# main task to compile and minify css
cssCompile = (task, params) ->
    try
      output = []

      # TODO: use glob to get set of files...
      # TODO: eventually make similar setup to js compile so we only accept
      #       the file that changes and cache the others...
      for fileOrDir in task.src
        # if directory loop over all top level files only
        if utils.isDirectory(fileOrDir)
          for file in fs.readdirSync(fileOrDir) when require.extensions[path.extname(file)]
            file = path.resolve(fileOrDir, file)
            output.push requireCss(file)
        else
          output.push requireCss(fileOrDir)

      # join and minify
      result = output.join("\n")
      result = uglifycss.processString(result) if task.argv.compress
      result
    catch ex
      task.handleError(ex, cmd in ['build'] )
      return ""

modules.exports=cssCompile
