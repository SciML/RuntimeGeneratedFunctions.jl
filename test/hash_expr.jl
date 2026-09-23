using Test
using RuntimeGeneratedFunctions

RuntimeGeneratedFunctions.init(@__MODULE__)

struct Scale
    k::Float64
end

mutable struct MutableScale
    k::Float64
end

for T in (Scale, MutableScale)
    @eval (s::$T)(x) = s.k * x
    @eval Base.show(io::IO, ::$T) = print(io, "Scale")
end

@testset "Embedded object cache identity" begin
    for T in (Scale, MutableScale)
        scale2, scale3 = T(2.0), T(3.0)
        f2 = @RuntimeGeneratedFunction(:(x -> $(scale2)(x)))
        f3 = @RuntimeGeneratedFunction(:(x -> $(scale3)(x)))
        f2_again = @RuntimeGeneratedFunction(:(x -> $(scale2)(x)))

        @test f2(1.0) == 2.0
        @test f3(1.0) == 3.0
        @test typeof(f2) !== typeof(f3)
        @test f2.body !== f3.body
        @test typeof(f2_again) === typeof(f2)
        @test f2_again.body === f2.body
    end

    f = @RuntimeGeneratedFunction(:(x -> $(Scale(2.0))(x)))
    f_again = @RuntimeGeneratedFunction(:(x -> $(Scale(2.0))(x)))
    @test typeof(f_again) === typeof(f)
    @test f_again.body === f.body

    plain = @RuntimeGeneratedFunction(:(x -> x + 1))
    plain_again = @RuntimeGeneratedFunction(:(x -> x + 1))
    @test plain_again.body === plain.body
end
