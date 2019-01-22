_l = require 'lodash'

# Paired down version of the coffeescript compiler entrypoint from  coffee-script/coffee-script.coffee.
# Webpack gets really angry if you try to just require() it directly.  Browserify doesn't.
# CoffeeScript was built for browserify.  Webpack picks up a bunch more require stuff that
# Browserify silently drops.  So, point Webpack?  But it makes our lives worse here. This is a
# stupid / gross hack.  I barely understand this code, and I've worked in the Coffee compiler
# before.  Ugh.  JRP 7/19/2017

parser = require('coffeescript/lib/coffee-script/parser').parser
Lexer = require('coffeescript/lib/coffee-script/lexer').Lexer
helpers = require 'coffeescript/lib/coffee-script/helpers'
config = require '../config'
{memoize_on} = require '../util'

lexer = new Lexer()
parser.lexer =
  lex: ->
    token = parser.tokens[@pos++]
    if token
      [tag, @yytext, @yylloc] = token
      parser.errorToken = token.origin or token
      @yylineno = @yylloc.first_line
    else
      tag = ''

    tag
  setInput: (tokens) ->
    parser.tokens = tokens
    @pos = 0
  upcomingInput: ->
    ""

parser.yy = require 'coffeescript/lib/coffee-script/nodes'

parser.yy.parseError = (message, {token}) ->
    {errorToken, tokens} = parser
    [errorTag, errorText, errorLoc] = errorToken
    errorText = switch
        when errorToken is tokens[tokens.length - 1]
            'end of input'
        when errorTag in ['INDENT', 'OUTDENT']
            'indentation'
        when errorTag in ['IDENTIFIER', 'NUMBER', 'INFINITY', 'STRING', 'STRING_START', 'REGEX', 'REGEX_START']
            errorTag.replace(/_START$/, '').toLowerCase()
        else
            helpers.nameWhitespaceCharacter errorText

    helpers.throwSyntaxError "unexpected #{errorText}", errorLoc

compile_coffee_cache = {}
exports.compile_coffee_expression = (expr) ->
    if config.memoize_coffee_compiler then memoize_on compile_coffee_cache, expr, -> _compile(expr) else _compile(expr)

_compile = (expr) ->
    code = "(=>(#{expr}))()"
    options = {bare: true}
    tokens = lexer.tokenize code, options
    fragments = parser.parse(tokens).compileToFragments(options)
    compiled = _l.map(fragments, 'code').join('')
    return compiled
