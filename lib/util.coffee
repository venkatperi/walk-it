prop = ( klass, name, spec ) ->
  throw new Error 'klass is not a class' unless klass.prototype?
  Object.defineProperty klass.prototype, name, spec
  
  
module.exports = 
  prop : prop
