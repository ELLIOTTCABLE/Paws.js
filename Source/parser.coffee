`require = require('./cov_require.js')(require)`
Paws = require './Paws.coffee'

class Parser
  labelCharacters = /[^(){} \n]/ # Not currently supporting quote-delimited labels

  constructor: (@text) ->
    @i = 0

  character: (char) ->
    @text[@i] is char && ++@i

  whitespace: ->
    true while @character(' ') || @character('\n')
    true

  label: ->
    @whitespace()
    start = @i
    res = ''
    while @text[@i] && labelCharacters.test(@text[@i])
      res += @text[@i++]
    res && new Paws.Label(res)

  parse: ->
    @label()

module.exports = parser =
  parse: (text) ->
    parser = new Parser(text)
    parser.parse()
  
  Expression: class Expression
