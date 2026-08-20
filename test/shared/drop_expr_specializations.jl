using RuntimeGeneratedFunctions

RuntimeGeneratedFunctions.init(@__MODULE__)
functions = [@RuntimeGeneratedFunction(:(x -> x + $i)) for i in 1:20]
foreach(drop_expr, functions)
