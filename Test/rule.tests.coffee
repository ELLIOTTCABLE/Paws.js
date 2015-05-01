assert = require 'assert'
sinon  = require 'sinon'
match  = sinon.match
expect = require('sinon-expect').enhance require('expect.js'), sinon, 'was'

Paws = require "../Source/Paws.coffee"
Paws.infect global # FIXME: Temporary.

describe "Paws' Rulebook support:", ->
   Rule = require '../Source/rule.coffee'
   Collection = Rule.Collection

   describe 'Rule', ->
      env = undefined
      beforeEach ->
         (new Collection).activate()
         env = {unit: new reactor.Unit, caller: new Execution}

      it 'should exist', ->
         expect(Rule).to.be.ok()
      it 'should construct', ->
         expect(-> new Rule env, 'a test', new Execution).not.to.throwException()

      it 'should convert titles to Labels', ->
         rule  = new Rule env, 'a test', new Execution
         expect(rule.title).to.be.a Label

      it 'should clone the locals of the environment', ->
         thing = new Thing
         env.caller = new Execution
         env.caller.locals.push thing
         body  = new Execution

         new Rule env, 'a test', body
         expect(body.locals).to.not.be env.caller.locals
         expect(body.locals.toArray()).to.contain thing

      it "should be able to inject things into the body's locals", ->
         body  = new Execution
         rule  = new Rule env, 'a test', body
         thing = new Thing

         rule.maintain_locals Thing.construct {key: thing}
         expect(body.locals.find('key')[0].valueish()).to.be thing

      it 'should be able to be dispatched', ->
         body  = sinon.spy()
         rule  = new Rule env, 'a test', new Native body

         rule.dispatch()
         expect(body).was.calledOnce()

      it 'should add itself to a passed collection', ->
         coll  = new Collection
         rule  = new Rule env, 'a test', new Execution, coll

         expect(coll.rules).to.contain rule

      it 'should add itself to the current collection if none is passed', ->
         coll  = new Collection
         coll.activate()
         rule  = new Rule env, 'a test', new Execution

         expect(coll.rules).to.contain rule

      it 'can be created without any Collection at all', ->
         expect(-> new Rule env, 'a test', new Execution).to.not.throwException()

      it 'should store status when when passed or failed', ->
         rule  = new Rule env, 'a test', new Execution
         rule.pass()
         expect(rule.status).to.be.ok()

         rule  = new Rule env, 'a test', new Execution
         rule.fail()
         expect(rule.status).to.not.be.ok()

      it 'should emit completion', ->
         listener = sinon.spy()
         rule  = new Rule env, 'a test', new Execution
         rule.on 'complete', listener

         rule.pass()
         expect(listener).was.calledOnce()

      it 'should emit completion, even after completion', ->
         listener = sinon.spy()
         rule  = new Rule env, 'a test', new Execution
         rule.pass()

         rule.on 'complete', listener
         expect(listener).was.calledOnce()

      describe '#eventually', ->
         it 'should take a block', ->
            rule   = new Rule env, 'a test', new Execution
            expect(-> rule.eventually new Execution).not.to.throwException()

         it 'should inject locals being maintained to the block passed', ->
            rule  = new Rule env, 'a test', new Execution
            thing = new Thing
            rule.maintain_locals Thing.construct {key: thing}

            block = new Execution
            rule.eventually block
            expect(block.locals.find('key')[0].valueish()).to.be thing

         it 'should ensure the eventually-block runs after exhaustion of the body', ->
            body  = sinon.spy()
            after = sinon.spy()
            rule  = new Rule env, 'a test', new Native body
            rule.eventually new Native after

            expect(body) .was.notCalled()
            expect(after).was.notCalled()
            rule.dispatch()
            expect(body) .was.calledOnce()
            expect(after).was.calledOnce()

         it 'should not allow the eventually-block to be invoked if the rule completes', ->
            body  = -> rule.pass()
            after = sinon.spy()
            rule  = new Rule env, 'a test', new Native body
            rule.eventually new Native after

            rule.dispatch()
            expect(after).was.notCalled()

      describe 'construct()', ->
         it 'should return null if no Rule can be constructed', ->
            rule = Rule.construct {}
            expect(rule).to.be null

         it 'should return a Rule', ->
            rule = Rule.construct {name: 'a test', body: 'pass[]'}
            expect(rule).to.be.a Rule

         it 'should set the rule title', ->
            rule = Rule.construct {name: 'a test', body: 'pass[]'}
            expect(rule.title.alien).to.be 'a test'

         it 'should construct the rule body', ->
            rule = Rule.construct {name: 'a test', body: 'pass[]'}

            expect(rule.body).to.be.an Execution
            expect(rule.body.current().valueOf()).to.be.a Label
            expect(rule.body.current().valueOf().alien).to.be 'pass'

         it 'should have a default title', ->
            rule = Rule.construct {body: 'pass[]'}
            expect(rule.title.alien).to.be '<untitled>'

         it 'should pend a body-less rule', ->
            rule = Rule.construct {name: 'a test'}

            expect(rule.body).to.be.a Native
            rule.unit.stage rule.body, undefined
            expect(rule.status).to.be 'NYI'

         it 'should generate a new Unit for each rule', ->
            rule = Rule.construct {name: 'a test', body: 'pass[]'}
            expect(rule.unit).to.be.a reactor.Unit

         it "should support an optional 'eventually' block", ->
            eventually = sinon.spy Rule::, 'eventually'

            rule = Rule.construct {name: 'a test', body: 'pass[]', eventually: 'fail[]'}
            expect(eventually).was.calledOnce()

         it "should accept string keywords to generate the 'eventually' block"

      describe 'Collections', ->
         it 'should exist', ->
            expect(Collection).to.be.ok()
         it 'should construct', ->
            expect(-> new Collection).not.to.throwException()

         it.skip 'should generate a new Collection when none exists.', ->
            # I can't think of a way to test this.
            expect(Collection.current()).to.be.a Collection

         it.skip "should change the global 'current' collection when created", ->
            # I can't think of any way to test this, either. ddis

         it 'can be selected as the current collection', ->
            coll = new Collection

            expect(Collection.current()).not.to.be coll
            coll.activate()
            expect(Collection.current()).to.be coll

         it 'can hold rules', ->
            coll = new Collection
            rule = new Rule env, 'a test', new Execution

            expect(coll.rules).to.not.contain rule
            coll.push rule
            expect(coll.rules).to.contain rule

         it "doesn't invoke rules when not dispatching", ->
            coll = new Collection
            test = sinon.spy()

            rule = new Rule env, 'a test', new Native test
            expect(test).was.notCalled()
            coll.push rule
            expect(test).was.notCalled()

         it 'dispatches rules', ->
            coll = new Collection
            rule = new Rule env, 'a test', new Execution, coll
            sinon.spy rule, 'dispatch'

            coll.dispatch()
            expect(rule.dispatch).was.calledOnce()

         it 'dispatches additional rules added while dispatching', ->
            coll = new Collection
            coll.dispatch()

            rule = new Rule env, 'a test', new Execution
            sinon.spy rule, 'dispatch'

            coll.push rule
            expect(rule.dispatch).was.calledOnce()

         it 'will not accept new rules after closing', ->
            coll = new Collection output: no
            coll.dispatch()

            rule = new Rule env, 'a test', new Execution, coll
            expect(coll.rules).to.have.length 1

            coll.close()
            rule = new Rule env, 'another test', new Execution, coll
            expect(coll.rules).to.have.length 1

         it 'completes when all rules have completed', ->
            listener = sinon.spy()
            coll = new Collection output: no
            coll.on 'complete', listener

            rule1 = new Rule env, 'a test', new Execution, coll
            rule2 = new Rule env, 'another test', new Execution, coll
            coll.close()

            rule1.pass()
            expect(listener).was.notCalled()
            rule2.pass()
            expect(listener).was.calledOnce()

         it 'prints nothing when not reporting', ->
            stream = { write: sinon.spy() }
            coll = new Collection stream

            rule = new Rule env, 'a test', new Execution, coll
            expect(stream.write).was.notCalled()
            rule.pass()
            expect(stream.write).was.notCalled()

         it 'prints a TAP header when reporting', ->
            stream = { write: sinon.spy() }
            coll = new Collection output: stream
            expect(stream.write).was.notCalled()

            coll.report()
            expect(stream.write).was.calledWith match "TAP version 13"

         it 'prints already-completed rules when reporting is called', ->
            stream = { write: sinon.spy() }
            coll = new Collection output: stream

            rule = new Rule env, 'a test', new Execution, coll
            rule.pass()
            expect(stream.write).was.notCalled()

            coll.report()
            expect(stream.write).was.calledWith match "ok 1 a test"

         it 'immediately prints rules on completion, when reporting', ->
            stream = { write: sinon.spy() }
            coll = new Collection output: stream
            coll.report()

            expect(stream.write).was.calledOnce()
            rule = new Rule env, 'a test', new Execution, coll
            rule.pass()
            expect(stream.write).was.calledWith match "ok 1 a test"

         it 'prints a ‘plan’ line after all rules have completed', ->
            stream = { write: sinon.spy() }
            coll = new Collection output: stream
            coll.report()

            expect(stream.write).was.calledOnce()
            rule = new Rule env, 'another test', new Execution, coll
            rule.pass()

            coll.close()
            expect(stream.write).was.calledWith match "1..1"
