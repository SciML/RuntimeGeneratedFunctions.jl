module RGFPrecompTest
    using RuntimeGeneratedFunctions
    RuntimeGeneratedFunctions.init(@__MODULE__)

    f = RuntimeGeneratedFunction(@__MODULE__, :((x,y)->x+y))
end
