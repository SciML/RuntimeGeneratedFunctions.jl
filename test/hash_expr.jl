using Test
using RuntimeGeneratedFunctions

RuntimeGeneratedFunctions.init(@__MODULE__)

struct Scale
    k::Float64
end

mutable struct MutableScale
    k::Float64
end

struct NumericLeaf <: Number
    value::Int
end

Base.show(io::IO, x::NumericLeaf) = print(io, x.value)
# Force a collision so the printed value must distinguish these numeric leaves.
Base.objectid(::NumericLeaf) = UInt(1)
Base.:(==)(a::MutableScale, b::MutableScale) = a.k == b.k

for T in (Scale, MutableScale)
    @eval (s::$T)(x) = s.k * x
    @eval Base.show(io::IO, ::$T) = print(io, "Scale")
end

@testset "Distinct numeric leaves retain their printed values" begin
    one, two = NumericLeaf(1), NumericLeaf(2)
    @test objectid(one) == objectid(two)
    @test string(one) != string(two)
    @test RuntimeGeneratedFunctions.expr_to_id(Expr(:tuple, one)) !=
        RuntimeGeneratedFunctions.expr_to_id(Expr(:tuple, two))
end

@testset "Equal but distinct mutable leaves retain their identities" begin
    scale1, scale2 = MutableScale(2.0), MutableScale(2.0)
    @test scale1 == scale2
    @test scale1 !== scale2

    f1 = @RuntimeGeneratedFunction(:(x -> $(scale1)(x)))
    f2 = @RuntimeGeneratedFunction(:(x -> $(scale2)(x)))
    @test f1(1.0) == f2(1.0) == 2.0
    @test typeof(f1) !== typeof(f2)
    @test f1.body !== f2.body
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
