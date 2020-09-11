module RGFPrecompTest
    using RuntimeGeneratedFunctions

    f = @RuntimeGeneratedFunction(:((x,y)->x+y))
end
