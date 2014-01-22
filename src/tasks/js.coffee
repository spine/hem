Dependency = require('./dependency')
Stitch     = require('./stitch')


class JsTask extends Task

  constructor: (app, config)  ->
    # for now forcing use of commonjs bundler
    config.commonjs or= 'required'
    # call parent
    super(app, config)

    # javascript only configurations
    @commonjs = config.commonjs

    # javascript to add before/after the stitch file
    @before   = utils.arrayToString(config.before or "")
    @after    = utils.arrayToString(config.after or "")

    # dependecy on other apps?
    @test     = config.test
    @depends  = utils.toArray(config.depends)

  # remove the files module from Stitch so its recompiled
  execute: (file) ->
    Stitch.clear(file) if file
    # extra logging for debug mode
    extra = (_argv.compress and " <b>--using compression</b>") or ""
    log.info("- Building target: <yellow>#{@target}</yellow>#{extra}")
    # compile source
    source = @compile()
    
    # TODO: run additional tasks or steps here...

    # determine if we need to write to filesystem
    write = _argv.command isnt "server"
    if source and write
      dirname = path.dirname(@target)
      fs.mkdirsSync(dirname) unless fs.existsSync(dirname)
      fs.writeFileSync(@target, source)
    source

  compile: ->
    try
      result = [@before, @compileLibs(), @compileModules(), @after].join("\n")
      result = uglifyjs.minify(result, {fromString: true}).code if _argv.compress
      result
    catch ex
      @handleExecuteError(ex)

  compileModules: ->
    @stitch or= new Stitch(@src)
    @depend or= new Dependency(@modules)
    _modules  = @depend.resolve().concat(@stitch.resolve())
    if _modules
      Stitch.template(@commonjs, _modules)
    else
      ""

  compileLibs: (files = @libs, parentDir = "") ->

    # TODO: need to perform similar operation as stitch in that only
    # compilable code is used... refactor Stitch class to handle this?? except
    # we don't want the code actually stitched in a template, just plain old js

    # check if folder or file
    results = []
    for file in files
      slash = if parentDir is "" then "" else path.sep
      file  = parentDir + slash + file
      if fs.existsSync(file)
        stats = fs.lstatSync(file)
        if (stats.isDirectory())
          dir = fs.readdirSync(file)
          results.push @compileLibs(dir, file)
        else if stats.isFile() and path.extname(file) in ['.js','.coffee']
          results.push fs.readFileSync(file, 'utf8')
    results.join("\n")


