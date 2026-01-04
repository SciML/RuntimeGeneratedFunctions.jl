module RGFPrecompTest2
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

y_in_RGFPrecompTest2 = 2

# Simulates a helper function which generates an RGF, but caches it in a
# different module.
function generate_rgf(cache_module)
    context_module = @__MODULE__
    return RuntimeGeneratedFunction(cache_module, @__MODULE__, :((x) -> y_in_RGFPrecompTest2 + x))
end
end
