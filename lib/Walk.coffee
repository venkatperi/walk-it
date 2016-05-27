_ = require 'lodash'
NodeVisitor = require './NodeVisitor'
{EventEmitter} = require 'events'

cloneOpts = ( opts, n, child, id, r ) ->
  x = _.assign {}, opts,
    { node : child, parent : n, id : id, parentRes : r }
  x.path = _.cloneDeep opts.path
  x

insert = ( obj, v, path ) ->
  path = '__root__' unless path?
  path = path.replace(']', '')
  sep = if path.indexOf('[') then '[' else '.'
  x = path.split(sep)
  if x.length > 1
    obj[ x[ 0 ] ] ?= if sep is '[' then [] else {}
    obj = obj[ x[ 0 ] ]
    x.shift()
  obj[ x[ 0 ] ] = v

###
Public: Walk Coffeescript's AST nodes

###
class Walk extends EventEmitter

  ###
  Public: Create AST Walker
  
  * `opt` {Object} options
    * `opt.node` {Object} the root CoffeeScript node
    * `opt.init` {Boolean} init meta data.
  
  If `init` is set, `astwalk` will perform an initial
  walk over the AST tree and append a meta object as well as two
  properties to each AST node:
      
    * `__id` A unique id (monotonically increasing count).
    * `__type` The type of AST node (`node.constructor.name`)
  
  ## AST Node Meta Information
  `astwalk` adds a property meta to Base which is the base class for
   Coffeescript AST node classes. meta provides meta-information
  about the node and in many cases, it rolls up information from
  child nodes which can ease navigation and manipulation of the AST.

  ###
  constructor : ( @node ) ->


    ###
    Public: Performs a walk -- calls the visitor for every node.

    * `depth` (optional) limits the walk up to `depth` levels
     from the **current** node (i.e. relative to the current node).
    * `context` (optional) {Object} is available to the visitor callback.


    ## About the Visitor: visitor(node)
    The current node is passed ot the visitor. Additionaly,
    the following properties are available in the `this` context
     of the visitor callback:
    * `@path` The `path` to the current node as an array of strings.
    * `@depth` The depth of the current node.
    * `@isRoot` True if the node is the root node.
    * `@isLeaf` True of the node is a leaf node.
    * `@id` The `id` used to invoke the current node, also the last
        element of the path array.
    * `@isAstNode` True if the node is a coffeescript AST node, or a
      scalar (string etc).
    * `@context` An optional context, passed to walk.
    * `@parent` The node's parent (undefined for root node).

    The visitor callback can invoke `@abort()` to terminate the walk early.

   **Visitor Return Value:** If a visitor returns an `{Object}`,
    the values from visiting the current AST node's child nodes are
    added to the object with the same key names as the original node.
    This can be viewed as a mapping operation on the AST tree (see example at
     the end).
    ###
  walk : ( context, depth, visitor ) =>
    throw new Error 'already walking' if @_isWalking
    if !depth and !visitor
      visitor = context
    else if !visitor
      [visitor, depth] = [ depth, context ]
    throw new Error 'Missing argument: visitor' unless visitor?

    @_walking true
    res = {}
    @_walk
      nodeVisitor : ( o ) -> new NodeVisitor o
      abort : @_abort
      node : @node,
      path : []
      visitor : visitor,
      context : context,
      ignore : ( x ) -> false
      maxDepth : depth or -1
      parentRes : res
    @_walking false
    res.__root__ or res

  each : ( f ) =>
    @walk ( x ) ->
      f x
      undefined

  map : ( f ) =>
    @walk ( x ) -> f x

  count : ( depth, f ) =>
    [f,depth] = switch arguments.length
      when 1 then [ depth ]
      else
        [ f, depth ]

    @reduce 0, ( x, acc ) -> if f.call @, x then acc + 1 else acc

  ###
  Public: Finds all nodes that satisfy the callback
  
  * `depth` (optional) {Number} limits the traversal depth
  * `f` {Function} is called with each node. The node is returned if `f`
   returns true.
  
  Returns array of {Object} ast nodes or undefined.
  ###
  findAll : ( depth, f ) =>
    [f, depth] = [ depth, f ] unless f?
    items = []
    @walk items, depth, ( x ) ->
      @context.push x if f.call @, x
      undefined
    items

  ###
  Public: Finds the first node that satisfies the callback
  
  * `depth` (optional) {Number} limits the traversal depth
  * `f` {Function} is called with each node. The node is returned if `f`
   returns true.
  
  Returns {Object}, the ast node or undefined.
  ###
  findFirst : ( depth, f ) =>
    [f, depth] = [ depth, f ] unless f?
    item = undefined
    @walk [], depth, ( x ) ->
      if  !item and f.call @, x
        item = x
        @abort()
      undefined
    item

  ###
  Public: Performs a `reduce` operation on the AST tree
  
  * `acc` The initial value of the accumulator
  * `f` {Function} called with each node: `f(node, acc)`.
  
  Updates an internal **accumulator** to the value returned by
  `f(node, acc)` and returns the final value of acc.

  Returns the final accumulator value.
  ###
  reduce : ( acc, depth, f ) =>
    [f, acc, depth] = switch arguments.length
      when 1 then [ acc ]
      when 2 then [ depth, acc ]
      else
        [ f, acc, depth ]

    @walk null, depth, ( x ) ->
      acc = f.call @, x, acc
      undefined
    acc

  _abort : ( err ) =>
    @_aborted = true
    @_error = err
    @emit 'abort', err

  _walking : ( val ) =>
    return if @_isWalking is val
    @_isWalking = val
    @emit if val then 'walk' else 'done'

  _walk : ( opts ) =>
    return unless opts?.node or @_aborted
    node = opts.node
    opts.path.push opts.id if opts.id?
    depth = opts.path.length

    checkDepth =
      opts.maxDepth < 0 or
        (opts.maxDepth >= 0 and
          depth < opts.maxDepth)

    @emit 'visit', opts
    nv = opts.nodeVisitor(opts)
    res = nv.visit()
    @emit 'visited', opts, res

    if res and opts.parentRes
      insert opts.parentRes, res, nv.id

    if _.isObjectLike(node) and checkDepth and !@_aborted
      opts.block = false
      for own attr, val of node when !opts.ignore(attr) and !opts.block
        if Array.isArray val
          for c,i in val
            @_walk cloneOpts opts, node, c, "#{attr}[#{i}]", res
        else
          @_walk cloneOpts opts, node, val, attr, res

    opts.parentRes or res

module.exports = Walk

