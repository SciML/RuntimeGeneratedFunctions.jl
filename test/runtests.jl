using Test
using RuntimeGeneratedFunctions, BenchmarkTools
using Serialization

const GROUP = get(ENV, "GROUP", "All")

if GROUP == "QA"
    using Pkg
    Pkg.activate(joinpath(@__DIR__, "qa"))
    Pkg.develop(PackageSpec(path = joinpath(@__DIR__, "..")))
    Pkg.instantiate()
    include(joinpath(@__DIR__, "qa", "qa.jl"))
end

if GROUP == "All" || GROUP == "Core"
    include(joinpath(@__DIR__, "core_tests.jl"))
end
