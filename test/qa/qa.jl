using RuntimeGeneratedFunctions, Aqua, ExplicitImports
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

@testset "ExplicitImports" begin
    @test ExplicitImports.check_no_implicit_imports(RuntimeGeneratedFunctions) === nothing
    @test ExplicitImports.check_no_stale_explicit_imports(RuntimeGeneratedFunctions) ===
        nothing
    @test ExplicitImports.check_all_explicit_imports_via_owners(RuntimeGeneratedFunctions) ===
        nothing
    @test ExplicitImports.check_all_qualified_accesses_via_owners(RuntimeGeneratedFunctions) ===
        nothing
    # `Base.deepcopy_internal` and `Serialization.serialize_type` are the
    # documented-by-convention extension points used to customize `deepcopy` and
    # `Serialization.serialize`, respectively. Neither owner declares them
    # public, but overriding/calling them is the only supported way to get the
    # required behavior, so they are ignored rather than rewritten.
    @test ExplicitImports.check_all_qualified_accesses_are_public(
        RuntimeGeneratedFunctions;
        ignore = (:deepcopy_internal, :serialize_type)
    ) === nothing
    @test ExplicitImports.check_all_explicit_imports_are_public(RuntimeGeneratedFunctions) ===
        nothing
end
