using RuntimeGeneratedFunctions, Aqua
@testset "Aqua" begin
    Aqua.find_persistent_tasks_deps(RuntimeGeneratedFunctions)
    Aqua.test_ambiguities(RuntimeGeneratedFunctions, recursive = false)
    Aqua.test_deps_compat(RuntimeGeneratedFunctions)
    Aqua.test_piracies(RuntimeGeneratedFunctions)
    Aqua.test_project_extras(RuntimeGeneratedFunctions)
    Aqua.test_stale_deps(RuntimeGeneratedFunctions)
    Aqua.test_unbound_args(RuntimeGeneratedFunctions)
    Aqua.test_undefined_exports(RuntimeGeneratedFunctions)
end
