_ = require 'lodash'
NodeVisitor = require './NodeVisitor'
{EventEmitter} = require 'events'
{leaf, Promise} = require './util'
log = require('taglog') 'Walk'

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
  walk : ( opts, visitor ) =>
    throw new Error 'already walking' if @_isWalking
    [visitor, opts] = [ opts ] if arguments.length is 1
    throw new Error 'Missing argument: visitor' unless visitor?

    @_walking true
    res = {}
    @_walk
      nodeVisitor : ( o ) -> new NodeVisitor o
      abort : @_abort
      node : @node,
      path : []
      visitor : visitor,
      context : opts?.context,
      ignore : -> false
      maxDepth : opts?.depth or -1
      parentRes : res
    .then =>
      @_walking false
      res.__root__ or res

  each : ( f ) =>
    log.v 'each'
    throw new Error 'Missing argument: f' unless f?
    @walk ( x ) -> f(x); undefined

  map : ( f ) =>
    log.v 'map'
    throw new Error 'Missing argument: f' unless f?
    @walk ( x ) -> f x

  count : ( opts, f ) =>
    log.v 'count', opts
    [f, opts] = [ opts ] if arguments.length is 1
    throw new Error 'Missing argument: f' unless f?
    @reduce initial : 0, depth : opts?.depth, ( x, acc ) ->
      if f.call(@, x) then acc + 1 else acc

  ###
  Public: Finds all nodes that satisfy the callback
  
  * `depth` (optional) {Number} limits the traversal depth
  * `f` {Function} is called with each node. The node is returned if `f`
   returns true.
  
  Returns array of {Object} ast nodes or undefined.
  ###
  findAll : ( opts, f ) =>
    log.v 'findAll', opts
    [f, opts] = [ opts ] if arguments.length is 1
    throw new Error 'Missing argument: f' unless f?
    items = []
    @walk context : items, depth : opts?.depth, ( x ) ->
      @context.push x if f.call @, x
      undefined
    .then -> items

  ###
  Public: Finds the first node that satisfies the callback
  
  * `depth` (optional) {Number} limits the traversal depth
  * `f` {Function} is called with each node. The node is returned if `f`
   returns true.
  
  Returns {Object}, the ast node or undefined.
  ###
  findFirst : ( opts, f ) =>
    log.v 'findFirst', opts
    [f, opts] = [ opts ] if arguments.length is 1
    throw new Error 'Missing argument: f' unless f?
    res = {}
    o = _.assign {}, opts
    o.context = {}
    @walk o, ( x ) ->
      if !@context.item and f.call @, x
        @context.item = x
        @abort()
      undefined
    .then -> o.context.item

  ###
  Public: Performs a `reduce` operation on the AST tree
  
  * `acc` The initial value of the accumulator
  * `f` {Function} called with each node: `f(node, acc)`.
  
  Updates an internal **accumulator** to the value returned by
  `f(node, acc)` and returns the final value of acc.

  Returns the final accumulator value.
  ###
  reduce : ( opts, f ) =>
    log.v 'reduce', opts
    [f, opts] = [ opts ] if arguments.length is 1
    throw new Error 'Missing argument: f' unless f?

    o = _.assign {}, opts
    o.context = { acc : opts?.initial }
    @walk o, ( x ) ->
      @context.acc = f.call @, x, @context.acc
      undefined
    .then -> o.context.acc

  _abort : ( err ) =>
    log.v 'aborted:', err
    @_aborted = true
    @_error = err
    @emit 'abort', err

  _walking : ( val ) =>
    return if @_isWalking is val
    @_isWalking = val
    status = if val then 'walk' else 'done'
    log.v 'status:', status
    @emit status

  _walk : ( opts ) =>
    new Promise ( resolve, reject ) =>
      setImmediate =>
        return resolve() if !opts?.node or @_aborted

        node = opts.node
        opts.path.push opts.id if opts.id?
        depth = opts.path.length

        checkDepth =
          opts.maxDepth < 0 or
            (opts.maxDepth >= 0 and
              depth < opts.maxDepth)

        @emit 'visiting', opts
        nv = opts.nodeVisitor(opts)
        res = nv.visit()
        @emit 'visited', opts, res

        if res and opts.parentRes
          insert opts.parentRes, res, nv.id

        if !leaf(node) and checkDepth and !@_aborted
          opts.block = false
          kids = for own attr, val of node when !opts.ignore(attr)
            if Array.isArray val
              Promise.all (for c,i in val
                @_walk cloneOpts opts, node, c, "#{attr}[#{i}]", res)
            else
              @_walk cloneOpts opts, node, val, attr, res

        r = -> resolve opts.parentRes or res
        if kids
          Promise.all(kids).then r
        else
          r()

module.exports = Walk

