using RuntimeGeneratedFunctions, SciMLTesting, Test

# `Base.deepcopy_internal` and `Serialization.serialize_type` are the
# documented-by-convention extension points used to customize `deepcopy` and
# `Serialization.serialize`, respectively. Neither owner declares them public, but
# overriding/calling them is the only supported way to get the required behavior,
# so they are ignored rather than rewritten.
run_qa(
    RuntimeGeneratedFunctions;
    explicit_imports = true,
    ei_kwargs = (;
        all_qualified_accesses_are_public = (; ignore = (:deepcopy_internal, :serialize_type)),
    ),
)
