# Hello! I am Paws! Come read about me, and find out how I work.
#
#                        ,d88b.d88b,
#                        88888888888
#                        `Y8888888Y'
#                          `Y888Y'
#                            `Y'


Paws = require './datagraph.coffee'

Paws.parse   = require './parser.coffee'
Paws.reactor = require './reactor.coffee'


Paws.init()
Paws.info "!! API initialized."

Paws.primitives = (bag)->
   require("./primitives/#{bag}.coffee")()

Paws.generateRoot = (code = '', name)->
   code = Paws.parse Paws.parse.prepare code if typeof code == 'string'
   code = new Execution code
   code.rename name if name
   Paws.info "~~ Root-execution generated for #{T.bold name}" if name

   code.locals.inject Paws.primitives 'infrastructure'
   code.locals.inject Paws.primitives 'implementation'

   return code

Paws.start =
Paws.js = (code)->
   root = Paws.generateRoot code

   here = new Paws.reactor.Unit
   here.stage root

   here.start()


Paws.infect = (globals)-> @utilities.infect globals, this


# XXX: Loading order:
#      0. Paws.coffee
#      1. += datagraph.coffee
#      2.    += utilities.coffee
#      3.       -> debugging.coffee...
#         += debugging.coffee (-> utilities.coffee...)
#      4. += parser.coffee
#      5. += reactor.coffee (-> utilities.coffee...)
#      6, += primitives/*

Paws.info "++ API available"
module.exports = Paws
