{extname} = require('path')
{wrap}    = require('module')
fs        = require('fs')
detective = require('detective')
commondir = require('commondir')
resolve   = require('./resolve')

compilers =
  js: (path) ->
    fs.readFileSync path, 'utf8'
    
try
  cs = require 'coffee-script'
  compilers.coffee = (path) ->
    cs.compile fs.readFileSync path, 'utf8'
catch err

try
  eco = require 'eco'
  if eco.precompile
    compilers.eco = (path) ->
      eco.precompile fs.readFileSync path, 'utf8'
catch errr

class Source
  @walk: ['js', 'coffee']
  
  @resolve: (path, name = '.', results = {}) ->
    [name, path] = resolve(name, path)
    
    # Return if we've already seen this file
    return if results[path]
    results[path] = source = new @(name, path)
    
    # Add other referenced scripts to the results object
    @resolve(dep, name, results) for dep in source.paths()
    return (value for key, value of results)
    
  constructor: (name, path) ->
    @name = name
    @path = path
    throw "no compiler: #{@path}" unless @valid()
    
  ext: ->
    extname(@path).slice(1)

  compile: ->
    @_compile or= compilers[@ext()](@path)
    
  module: ->
    wrap(@compile())
  
  paths: ->
    if @ext() in @constructor.walk
      # Find `require()` calls
      paths = detective.find(@compile())
      
      # Check that there are no dynamic `require()` calls
      if paths.expressions.length
        throw 'Expressions in require() statements'
      
      paths.strings
    else 
      []

  valid: ->
    !!compilers[@ext()]

class Package
  constructor: (config = {}) ->
    @identifier  = config.identifier ? 'require'
    @libs        = config.libs  ? []
    @paths       = config.paths ? []
    @paths       = [@paths] if typeof @paths is 'string'
  
  compile: ->
    sources = []
    sources = sources.concat Source.resolve(path) for path in @paths
    (source.module() for source in sources).join("\n")
    
  createServer: ->
    (req, res, next) =>
      res.writeHead 200, 'Content-Type': 'text/javascript'
      res.end @compile()

module.exports = 
  compilers:  compilers
  Source:     Source
  Package:    Package
  createPackage: (config) -> 
    new Package(config)