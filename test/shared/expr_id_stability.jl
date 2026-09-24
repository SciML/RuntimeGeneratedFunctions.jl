# Prints the ids of RGFs embedding objects from a module created in this
# process, whose build id (and so `objectid` of its types) is new each session.

using RuntimeGeneratedFunctions

module EmbeddedObjects
    struct Scale
        k::Float64
    end
    (s::Scale)(x) = s.k * x
    halve(x) = x / 2
end

RuntimeGeneratedFunctions.init(@__MODULE__)

using .EmbeddedObjects: Scale, halve

fs = (
    @RuntimeGeneratedFunction(:(x -> $(Scale(2.0))(x))),
    @RuntimeGeneratedFunction(:(x -> $(halve)(x) + $(GlobalRef(EmbeddedObjects, :halve))(x))),
    @RuntimeGeneratedFunction(:(x -> $([1.0, 2.0]) .* x + $(Scale)(3.0)(x))),
)
for f in fs
    println(RuntimeGeneratedFunctions._id(f))
end
