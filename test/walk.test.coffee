should = require 'should'
assert = require 'assert'
Walk = require '../lib/Walk'
log = require('taglog') 'walk.test'
log.level 'verbose'

pkg = require '../package.json'

describe 'Walk', ->

  obj = undefined
  p = w = undefined
  beforeEach ->
    obj = { a : 1, b : { c : 2, d : { e : [ 7, 8, 9 ] } } }
    w = new Walk obj
    p = new Walk pkg

  it 'should visit all nodes', (done) ->
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

  it 'find all', ->
    items = w.findAll -> @isLeaf
    items.should.eql [ 1, 2, 7, 8, 9 ]

  it 'reduce (count leaves)', ->
    res = w.reduce initial : 0, ( x, acc ) ->
      if @isLeaf then acc + 1 else acc
    res.should.equal 5

  it 'count non leaves', ->
    res = w.count -> !@isLeaf
    res.should.equal 3

  it 'count - leaf + non leaf nodes = total nodes', ->
    leaves = w.count -> @isLeaf
    nonLeaves = w.count -> !@isLeaf
    total = w.count -> true
    assert.equal total, leaves + nonLeaves

  it 'findAll - all string in package.json', ->
    items = p.findAll (x) -> typeof x is 'string'
    #console.log items

  it 'findFirst - with id', ->
    name = p.findFirst (x) ->
      @id is 'name'
    assert.equal name, 'walk-it'

  it 'should abort immediately', ->

  describe 'events', ->
  


