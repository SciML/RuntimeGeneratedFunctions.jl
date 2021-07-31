# Must be run in a separate process from the rest of the tests!

using RuntimeGeneratedFunctions
using Serialization

RuntimeGeneratedFunctions.init(@__MODULE__)

f = @RuntimeGeneratedFunction(:(x->"Hi from a separate process. x=$x"))

serialize(stdout, f)
