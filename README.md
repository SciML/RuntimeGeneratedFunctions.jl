# RuntimeGeneratedFunctions.jl

[![Join the chat at https://julialang.zulipchat.com #sciml-bridged](https://img.shields.io/static/v1?label=Zulip&message=chat&color=9558b2&labelColor=389826)](https://julialang.zulipchat.com/#narrow/stream/279055-sciml-bridged)
[![Global Docs](https://img.shields.io/badge/docs-SciML-blue.svg)](https://docs.sciml.ai/RuntimeGeneratedFunctions/stable/)

[![codecov](https://codecov.io/gh/SciML/RuntimeGeneratedFunctions.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/SciML/RuntimeGeneratedFunctions.jl)
[![Build Status](https://github.com/SciML/RuntimeGeneratedFunctions.jl/workflows/CI/badge.svg)](https://github.com/SciML/RuntimeGeneratedFunctions.jl/actions?query=workflow%3ACI)

[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor%27s%20Guide-blueviolet)](https://github.com/SciML/ColPrac)
[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)

`RuntimeGeneratedFunctions` are functions generated at runtime without world-age
issues and with the full performance of a standard Julia anonymous function. This
builds functions in a way that avoids `eval`.

Note that `RuntimeGeneratedFunction` does not handle closures. Please use the
[GeneralizedGenerated.jl](https://github.com/JuliaStaging/GeneralizedGenerated.jl)
package for more flexible staged programming. While `GeneralizedGenerated.jl` is
more powerful, `RuntimeGeneratedFunctions.jl` handles large expressions better.

## Tutorials and Documentation

For information on using the package,
[see the stable documentation](https://docs.sciml.ai/RuntimeGeneratedFunctions/stable/). Use the
[in-development documentation](https://docs.sciml.ai/RuntimeGeneratedFunctions/dev/) for the version of
the documentation, which contains the unreleased features.

## Simple Example

Here's an example showing how to construct and immediately call a runtime
generated function:

```julia
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

function no_worldage()
    ex = :(function f(_du, _u, _p, _t)
        @inbounds _du[1] = _u[1]
        @inbounds _du[2] = _u[2]
        nothing
    end)
    f1 = @RuntimeGeneratedFunction(ex)
    du = rand(2)
    u = rand(2)
    p = nothing
    t = nothing
    f1(du, u, p, t)
end
no_worldage()
```

## Changing how global symbols are looked up

If you want to use helper functions or global variables from a different
module within your function expression you'll need to pass a `context_module`
to the `@RuntimeGeneratedFunction` constructor. For example

```julia
RuntimeGeneratedFunctions.init(@__MODULE__)

module A
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(A)
helper_function(x) = x + 1
end

function g()
    expression = :(f(x) = helper_function(x))
    # context module is `A` so that `helper_function` can be found.
    f = @RuntimeGeneratedFunction(A, expression)
    @show f(1)
end
```

## Precompilation and setting the function expression cache

For technical reasons RuntimeGeneratedFunctions needs to cache the function
expression in a global variable within some module. This is normally
transparent to the user, but if the `RuntimeGeneratedFunction` is evaluated
during module precompilation, the cache module must be explicitly set to the
module currently being precompiled. This is relevant for helper functions in
some module which construct a RuntimeGeneratedFunction on behalf of the user.
For example, in the following code, any third party user of
`HelperModule.construct_rgf()` user needs to pass their own module as the
`cache_module` if they want the returned function to work after precompilation:

```julia
RuntimeGeneratedFunctions.init(@__MODULE__)

# Imagine HelperModule is in a separate package and will be precompiled
# separately.
module HelperModule
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(HelperModule)

function construct_rgf(cache_module, context_module, ex)
    ex = :((x) -> $ex^2 + x)
    RuntimeGeneratedFunction(cache_module, context_module, ex)
end
end

function g()
    ex = :(x + 1)
    # Here cache_module is set to the module currently being compiled so that
    # the returned RGF works with Julia's module precompilation system.
    HelperModule.construct_rgf(@__MODULE__, @__MODULE__, ex)
end

f = g()
@show f(1)
```

## Retrieving Expressions

From a constructed RuntimeGeneratedFunction, you can retrieve the expressions using the
`RuntimeGeneratedFunctions.get_expression` command. For example:

```julia
ex = :((x) -> x^2)
rgf = @RuntimeGeneratedFunction(ex)
julia> RuntimeGeneratedFunctions.get_expression(rgf)
#=
quote
    #= c:\Users\accou\OneDrive\Computer\Desktop\test.jl:39 =#
    x ^ 2
end
=#
```

This can be used to get the expression even if `drop_expr` has been performed.

### Example: Retrieving Expressions from ModelingToolkit.jl

[ModelingToolkit.jl](https://github.com/SciML/ModelingToolkit.jl) uses
RuntimeGeneratedFunctions.jl for the construction of its functions to avoid issues of
world-age. Take for example its tutorial:

```julia
using ModelingToolkit, RuntimeGeneratedFunctions
using ModelingToolkit: t_nounits as t, D_nounits as D

@mtkmodel FOL begin
    @parameters begin
        τ # parameters
    end
    @variables begin
        x(t) # dependent variables
    end
    @equations begin
        D(x) ~ (1 - x) / τ
    end
end

using DifferentialEquations: solve
@mtkbuild fol = FOL()
prob = ODEProblem(fol, [fol.x => 0.0], (0.0, 10.0), [fol.τ => 3.0])
```

If we check the function:

```julia
julia> prob.f
(::ODEFunction{true, SciMLBase.AutoSpecialize, ModelingToolkit.var"#f#697"{RuntimeGeneratedFunction{(:ˍ₋arg1, :ˍ₋arg2, :t), ModelingToolkit.var"#_RGF_ModTag", ModelingToolkit.var"#_RGF_ModTag", (0x2cce5cf2, 0xd20b0d73, 0xd14ed8a6, 0xa4d56c4f, 0x72958ea1), Nothing}, RuntimeGeneratedFunction{(:ˍ₋out, :ˍ₋arg1, :ˍ₋arg2, :t), ModelingToolkit.var"#_RGF_ModTag", ModelingToolkit.var"#_RGF_ModTag", (0x7f3c227e, 0x8f116bb1, 0xb3528ad5, 0x9c57c605, 0x60f580c3), Nothing}}, UniformScaling{Bool}, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, ModelingToolkit.var"#852#generated_observed#706"{Bool, ODESystem, Dict{Any, Any}, Vector{Any}}, Nothing, ODESystem, Nothing, Nothing}) (generic function with 1 method)
```

It's a RuntimeGeneratedFunction. We can find the code for this system using the retrieval
command on the function we want. For example, for the in-place function:

```julia
julia> RuntimeGeneratedFunctions.get_expression(prob.f.f.f_iip)

:((ˍ₋out, ˍ₋arg1, ˍ₋arg2, t)->begin
          #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:373 =#
          #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:374 =#
          #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:375 =#
          begin
              begin
                  begin
                      #= C:\Users\accou\.julia\packages\Symbolics\HIg7O\src\build_function.jl:546 =#
                      #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:422 =# @inbounds begin
                              #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:418 =#
                              ˍ₋out[1] = (/)((+)(1, (*)(-1, ˍ₋arg1[1])), ˍ₋arg2[1])
                              #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:420 =#
                              nothing
                          end
                  end
              end
          end
      end)
```

or the out-of-place function:

```julia
julia> RuntimeGeneratedFunctions.get_expression(prob.f.f.f_oop)
:((ˍ₋arg1, ˍ₋arg2, t)->begin
          #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:373 =#
          #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:374 =#
          #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:375 =#
          begin
              begin
                  begin
                      #= C:\Users\accou\.julia\packages\SymbolicUtils\c0xQb\src\code.jl:468 =#
                      (SymbolicUtils.Code.create_array)(typeof(ˍ₋arg1), nothing, Val{1}(), Val{(1,)}(), (/)((+)(1, (*)(-1, ˍ₋arg1[1])), ˍ₋arg2[1]))
                  end
              end
          end
      end)
```
