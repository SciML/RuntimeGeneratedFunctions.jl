using SciMLTesting

# core_tests.jl must run in `Main` (not an isolated @safetestset module): it
# deserializes RuntimeGeneratedFunctions produced by a separate process whose
# module tag is `Main.#_RGF_ModTag`, so the body must be evaluated where
# `RuntimeGeneratedFunctions.init(@__MODULE__)` initializes `Main`. A thunk runs
# in the caller's (Main) scope; folder-discovery's @safetestset isolation cannot
# express this, so Core is an explicit thunk while QA uses the standard sub-env.
run_tests(;
    core = () -> include(joinpath(@__DIR__, "core_tests.jl")),
    qa = (; env = joinpath(@__DIR__, "qa"), body = joinpath(@__DIR__, "qa", "qa.jl")),
)
