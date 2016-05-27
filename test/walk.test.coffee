should = require 'should'
assert = require 'assert'
Walk = require '../lib/Walk'

describe 'Walk', ->

  obj = undefined
  w = undefined
  beforeEach ->
    obj = { a : 1, b : { c : 2, d : { e : [ 7, 8, 9 ] } } }
    w = new Walk obj

  it 'should visit all nodes', ->
    count = 0
    items = []
    w.walk ( x ) ->
      count++
      items.push x if @isLeaf
      undefined
    count.should.equal 8
    items.should.eql [ 1, 2, 7, 8, 9 ]

  it 'find all', ->
    items = w.findAll -> @isLeaf
    items.should.eql [ 1, 2, 7, 8, 9 ]

  it 'reduce', ->
    res = w.reduce 0, ( x, acc ) -> if @isLeaf then acc + 1 else acc
    res.should.equal 5

  it 'count', ->
    res = w.count -> @isLeaf
    res.should.equal 5

  it 'should abort immediately', ->

  describe 'events', ->
  


