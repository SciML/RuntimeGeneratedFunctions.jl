# RuntimeGeneratedFunctions.jl: Generate functions at runtime

`RuntimeGeneratedFunctions` are functions generated at runtime without world-age
issues and with the full performance of a standard Julia anonymous function. This
builds functions in a way that avoids `eval`.

Note that `RuntimeGeneratedFunction` does not handle closures. Please use the
[GeneralizedGenerated.jl](https://github.com/JuliaStaging/GeneralizedGenerated.jl)
package for more fixable staged programming. While `GeneralizedGenerated.jl` is
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
module within your function expression, you'll need to pass a `context_module`
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

For technical reasons, RuntimeGeneratedFunctions needs to cache the function
expression in a global variable within some module. This is normally
transparent to the user, but if the `RuntimeGeneratedFunction` is evaluated
during module precompilation, the cache module must be explicitly set to the
module currently being precompiled. This is relevant for helper functions in
some module, which construct a RuntimeGeneratedFunction on behalf of the user.
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

## Reproducibility

```@raw html
<details><summary>The documentation of this SciML package was built using these direct dependencies,</summary>
```

```@example
using Pkg # hide
Pkg.status() # hide
```

```@raw html
</details>
```

```@raw html
<details><summary>and using this machine and Julia version.</summary>
```

```@example
using InteractiveUtils # hide
versioninfo() # hide
```

```@raw html
</details>
```

```@raw html
<details><summary>A more complete overview of all dependencies and their versions is also provided.</summary>
```

```@example
using Pkg # hide
Pkg.status(; mode = PKGMODE_MANIFEST) # hide
```

```@raw html
</details>
```

```@eval
using TOML
using Markdown
version = TOML.parse(read("../../Project.toml", String))["version"]
name = TOML.parse(read("../../Project.toml", String))["name"]
link_manifest = "https://github.com/SciML/" * name * ".jl/tree/gh-pages/v" * version *
                "/assets/Manifest.toml"
link_project = "https://github.com/SciML/" * name * ".jl/tree/gh-pages/v" * version *
               "/assets/Project.toml"
Markdown.parse("""You can also download the
[manifest]($link_manifest)
file and the
[project]($link_project)
file.
""")
```
