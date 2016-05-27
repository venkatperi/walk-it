_ = require 'lodash'
Q = require 'q'

prop = ( klass, name, spec ) ->
  throw new Error 'klass is not a class' unless klass.prototype?
  Object.defineProperty klass.prototype, name, spec

module.exports =
  prop : prop
  leaf : ( x ) -> !_.isObjectLike(x)
  Promise : Q.Promise