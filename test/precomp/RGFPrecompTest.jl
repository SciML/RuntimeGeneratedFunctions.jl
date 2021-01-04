module RGFPrecompTest
    using RuntimeGeneratedFunctions
    RuntimeGeneratedFunctions.init(@__MODULE__)

    f = @RuntimeGeneratedFunction(:((x,y)->x+y))
end
