module RGFPrecompTest
    using RuntimeGeneratedFunctions
    RuntimeGeneratedFunctions.init(@__MODULE__)
    
    z = 100
    f = @RuntimeGeneratedFunction(:((x,y)->x+y+z))
    f2 = RuntimeGeneratedFunction(@__MODULE__, :((x,y)->x-y+z))

    function build_RGF(ex, mod=@__MODULE__)
        # This function is used to test out a consumer module (i.e. a module
        # that calls this module's function) in the RGFPrecompConsumerTest.
        RuntimeGeneratedFunction(mod, ex)
    end

    module Submodule
        using RuntimeGeneratedFunctions
        RuntimeGeneratedFunctions.init(@__MODULE__)

        z = 200
        f = @RuntimeGeneratedFunction(:((x,y)->x*y+z))

        # Define a version in the parent scope (i.e. using the parent module's "z")
        f2 = RuntimeGeneratedFunction(parentmodule(@__MODULE__), :((x,y)->x/y+z))  
    end
end
