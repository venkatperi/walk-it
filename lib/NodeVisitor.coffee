_ = require 'lodash'
{prop, leaf} = require './util'

class NodeVisitor
  prop @, 'path', get : -> @opts.path
  prop @, 'depth', get : -> @opts.length
  prop @, 'isRoot', get : -> @opts.length is 0
  prop @, 'id', get : -> @opts.path[ -1.. ][ 0 ]
  prop @, 'parent', get : -> @opts.parent
  prop @, 'context', get : -> @opts.context
  prop @, 'isLeaf', get : -> leaf @opts.node

  constructor : ( @opts ) ->

  visit : =>
    try
      @opts.visitor.call @, @opts.node
    catch err
      @abort err

  abort : ( val ) => @opts.abort val

  block : => @opts.block = true

module.exports = NodeVisitor
