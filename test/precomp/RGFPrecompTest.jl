module RGFPrecompTest
    using RuntimeGeneratedFunctions
    using RGFPrecompTest2
    RuntimeGeneratedFunctions.init(@__MODULE__)

    f = @RuntimeGeneratedFunction(:((x,y)->x+y))

    g = RGFPrecompTest2.generate_rgf(@__MODULE__)
end
