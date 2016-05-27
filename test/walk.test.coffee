should = require 'should'
assert = require 'assert'
Walk = require '../lib/Walk'
log = require('taglog') 'walk.test'
Q  = require 'q'
#log.level 'verbose'

pkg = require '../package.json'

describe 'Walk', ->

  obj = undefined
  p = w = undefined
  beforeEach ->
    obj = { a : 1, b : { c : 2, d : { e : [ 7, 8, 9 ] } } }
    w = new Walk obj
    p = new Walk pkg

  it 'should visit all nodes', ( done ) ->
    count = 0
    items = []
    w.walk ( x ) ->
      count++
      items.push x if @isLeaf
      undefined
    .then ->
      count.should.equal 8
      items.should.eql [ 1, 2, 7, 8, 9 ]
      done()
    .fail done

  it 'find all', ( done ) ->
    w.findAll -> @isLeaf
    .then ( items ) ->
      items.should.eql [ 1, 2, 7, 8, 9 ]
      done()
    .fail done

  it 'reduce (count leaves)', ( done ) ->
    w.reduce initial : 0, ( x, acc ) ->
      if @isLeaf then acc + 1 else acc
    .then ( res ) ->
      res.should.equal 5
      done()
    .fail done

  it 'count non leaves', ( done ) ->
    w.count -> !@isLeaf
    .then ( res ) ->
      res.should.equal 3
      done()
    .fail done

  it 'count - leaf + non leaf nodes = total nodes', ( done ) ->
    Q.spread [
      (new Walk(obj).count -> @isLeaf),
      (new Walk(obj).count -> !@isLeaf),
      (new Walk(obj).count -> true) ]
    , ( leaves, nonLeaves, total ) ->
      assert.equal total, leaves + nonLeaves
      done()
    .fail done

  it 'findAll - all string in package.json', ( done ) ->
    p.findAll ( x ) -> typeof x is 'string'
    .then ( items ) ->
      assert.equal items[0], 'walk-it'
      #console.log items
      done()
    .fail done

  it 'findFirst - with id', ( done ) ->
    p.findFirst -> @id is 'name'
    .then ( name ) ->
      assert.equal name, 'walk-it'
      done()
    .fail done

  #it 'should abort immediately', ( done ) ->

  describe 'events', -> 
  


