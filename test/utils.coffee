should = require('should')
utils  = require('../lib/utils')

describe 'utility class', ->
  it 'should parse template', ->
    template = "variable should equal {{ variable }}"
    result = utils.tmplStr template, variable: "test"
    result.should.equal("variable should equal test")

