# RuntimeGeneratedFunctions.jl

[![Build Status](https://github.com/SciML/RuntimeGeneratedFunctions.jl/workflows/CI/badge.svg)](https://github.com/SciML/RuntimeGeneratedFunctions.jl/actions?query=workflow%3ACI)

`RuntimeGeneratedFunctions` are functions generated at runtime without world-age
issues and with the full performance of a standard Julia anonymous function. This
builds functions in a way that avoids `eval`.

Note that `RuntimeGeneratedFunction` does not handle closures. Please use the
[GeneralizedGenerated.jl](https://github.com/JuliaStaging/GeneralizedGenerated.jl)
package for more fixable staged programming. While `GeneralizedGenerated.jl` is
more powerful, `RuntimeGeneratedFunctions.jl` handles large expressions better.

Credit to Chris Foster (@c4tf) for the implementation idea.

## Example

```julia
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

function no_worldage()
    ex = :(function f(_du,_u,_p,_t)
        @inbounds _du[1] = _u[1]
        @inbounds _du[2] = _u[2]
        nothing
    end)
    f1 = @RuntimeGeneratedFunction(ex)
    du = rand(2)
    u = rand(2)
    p = nothing
    t = nothing
    f1(du,u,p,t)
end
no_worldage()
```
