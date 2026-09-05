using Pkg

Pkg.add(PackageSpec(name = "PrecompileTools", version = "1.2.1"))
Pkg.develop(path = only(ARGS))

using RuntimeGeneratedFunctions

RuntimeGeneratedFunctions.init(@__MODULE__)
increment = @RuntimeGeneratedFunction(:(x -> x + 1))
@assert increment(41) == 42
