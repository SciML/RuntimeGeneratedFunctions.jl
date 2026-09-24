module RGFPrecompTest
using RuntimeGeneratedFunctions
using RGFPrecompTest2
RuntimeGeneratedFunctions.init(@__MODULE__)

f = @RuntimeGeneratedFunction(:((x, y) -> x + y))

g = RGFPrecompTest2.generate_rgf(@__MODULE__)

struct Offset
    k::Int
end
(o::Offset)(x) = x + o.k
offset_expr() = :(x -> $(Offset(5))(x) * $(Int32(2)))
h = @RuntimeGeneratedFunction(offset_expr())
end
