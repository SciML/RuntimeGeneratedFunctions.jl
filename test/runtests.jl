using Test
using SafeTestsets
using RuntimeGeneratedFunctions

# Serialization resolves an RGF's cache/module tag type by name against the
# receiving process's `Main`. The serialize round-trip test deserializes an RGF
# produced by serialize_rgf.jl, which ran `init` in its own `Main`, so `Main`
# here must also be initialized for that tag to be defined.
RuntimeGeneratedFunctions.init(@__MODULE__)

const GROUP = get(ENV, "GROUP", "All")

if GROUP == "QA"
    using Pkg
    Pkg.activate(joinpath(@__DIR__, "qa"))
    Pkg.develop(PackageSpec(path = joinpath(@__DIR__, "..")))
    Pkg.instantiate()
    include(joinpath(@__DIR__, "qa", "qa.jl"))
end

if GROUP == "All" || GROUP == "Core"
    @safetestset "Core" begin
        include("core_tests.jl")
    end
end
