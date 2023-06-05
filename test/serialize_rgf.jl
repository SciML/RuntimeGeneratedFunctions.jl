# Must be run in a separate process from the rest of the tests!

using RuntimeGeneratedFunctions
using Serialization

RuntimeGeneratedFunctions.init(@__MODULE__)

f = @RuntimeGeneratedFunction(:(x -> "Hi from a separate process. x=$x"))
g = drop_expr(@RuntimeGeneratedFunction(:(y -> "Serialization with dropped body. y=$y")))

serialize(stdout, (f, g))
