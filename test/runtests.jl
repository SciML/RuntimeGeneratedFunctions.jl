using RuntimeGeneratedFunctions, BenchmarkTools
using Serialization
using Test

RuntimeGeneratedFunctions.init(@__MODULE__)

function f(_du, _u, _p, _t)
    @inbounds _du[1] = _u[1]
    @inbounds _du[2] = _u[2]
    nothing
end

ex1 = :((_du, _u, _p, _t) -> begin
    @inbounds _du[1] = _u[1]
    @inbounds _du[2] = _u[2]
    nothing
end)

ex2 = :(function f(_du, _u, _p, _t)
    @inbounds _du[1] = _u[1]
    @inbounds _du[2] = _u[2]
    nothing
end)

ex3 = :(function (_du::T, _u::Vector{E}, _p::P, _t::Any) where {T <: Vector, E, P}
    @inbounds _du[1] = _u[1]
    @inbounds _du[2] = _u[2]
    nothing
end)

f1 = @RuntimeGeneratedFunction(ex1)
f2 = @RuntimeGeneratedFunction(ex2)
f3 = @RuntimeGeneratedFunction(ex3)

@test f1 isa Function

du = rand(2)
u = rand(2)
p = nothing
t = nothing

@test f1(du, u, p, t) === nothing
du == u
du = rand(2)
f2(du, u, p, t)
@test du == u
du = rand(2)
@test f3(du, u, p, t) === nothing
du == u

t1 = @belapsed $f($du, $u, $p, $t)
t2 = @belapsed $f1($du, $u, $p, $t)
t3 = @belapsed $f2($du, $u, $p, $t)
t4 = @belapsed $f3($du, $u, $p, $t)

@test t1≈t2 atol=3e-9
@test t1≈t3 atol=3e-9
@test t1≈t4 atol=3e-9

function no_worldage()
    ex = :(function f(_du, _u, _p, _t)
        @inbounds _du[1] = _u[1]
        @inbounds _du[2] = _u[2]
        nothing
    end)
    f1 = @RuntimeGeneratedFunction(ex)
    du = rand(2)
    u = rand(2)
    p = nothing
    t = nothing
    f1(du, u, p, t)
end
@test no_worldage() === nothing

# Test show()
@test sprint(show, MIME"text/plain"(),
    @RuntimeGeneratedFunction(Base.remove_linenums!(:((x, y) -> x + y + 1)))) ==
      """
      RuntimeGeneratedFunction(#=in $(@__MODULE__)=#, #=using $(@__MODULE__)=#, :((x, y)->begin
                x + y + 1
            end))"""

# Test with precompilation
push!(LOAD_PATH, joinpath(@__DIR__, "precomp"))
using RGFPrecompTest

@test RGFPrecompTest.f(1, 2) == 3
@test RGFPrecompTest.g(40) == 42

# Test that RuntimeGeneratedFunction with identical body expressions (but
# allocated separately) don't clobber each other when one is GC'd.
f_gc = @RuntimeGeneratedFunction(Base.remove_linenums!(:((x, y) -> x + y + 100001)))
let
    @RuntimeGeneratedFunction(Base.remove_linenums!(:((x, y) -> x + y + 100001)))
end
GC.gc()
@test f_gc(1, -1) == 100001

# Test that drop_expr works
f_drop1, f_drop2 = let
    ex = Base.remove_linenums!(:(x -> x - 1))
    # Construct two identical RGFs here to test the cache deduplication code
    (drop_expr(@RuntimeGeneratedFunction(ex)),
        drop_expr(@RuntimeGeneratedFunction(ex)))
end
GC.gc()
@test f_drop1(1) == 0
@test f_drop2(1) == 0

# Test that threaded use works
tasks = []
for k in 1:4
    let k = k
        t = Threads.@spawn begin
            r = Bool[]
            for i in 1:100
                f = @RuntimeGeneratedFunction(Base.remove_linenums!(:((x, y) -> x + y +
                                                                                $i * $k)))
                x = 1
                y = 2
                push!(r, f(x, y) == x + y + i * k)
            end
            r
        end
        push!(tasks, t)
    end
end
@test all(all.(fetch.(tasks)))

# Test that globals are resolved within the correct scope

module GlobalsTest
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

y_in_GlobalsTest = 40
f = @RuntimeGeneratedFunction(:(x -> x + y_in_GlobalsTest))
end

@test GlobalsTest.f(2) == 42

f_outside = @RuntimeGeneratedFunction(GlobalsTest, :(x -> x + y_in_GlobalsTest))
@test f_outside(2) == 42

@test_throws ErrorException @eval(module NotInitTest
using RuntimeGeneratedFunctions
# RuntimeGeneratedFunctions.init(@__MODULE__) # <-- missing
f = @RuntimeGeneratedFunction(:(x -> x + y))
end)

# closures
if VERSION >= v"1.7.0-DEV.351"
    ex = :(x -> (y -> x + y))
    @test @RuntimeGeneratedFunction(ex)(2)(3) === 5

    ex = :(x -> (f(y::Int)::Float64 = x + y; f))
    @test @RuntimeGeneratedFunction(ex)(2)(3) === 5.0

    ex = :(x -> function (y::Int)
        return x + y
    end)
    @test @RuntimeGeneratedFunction(ex)(2)(3) === 5

    ex = :(x -> function f(y::Int)::UInt8
        return x + y
    end)
    @test @RuntimeGeneratedFunction(ex)(2)(3) === 0x05

    ex = :(x -> sum(i^2 for i in 1:x))
    @test @RuntimeGeneratedFunction(ex)(3) === 14

    ex = :(x -> [2i for i in 1:x])
    @test @RuntimeGeneratedFunction(ex)(3) == [2, 4, 6]
end

# Serialization

proj = dirname(Base.active_project())
buf = IOBuffer(read(`$(Base.julia_cmd()) --startup-file=no --project=$proj "serialize_rgf.jl"`))
deserialized_f, deserialized_g = deserialize(buf)
@test deserialized_f(11) == "Hi from a separate process. x=11"
@test deserialized_f.body isa Expr
@test deserialized_g(12) == "Serialization with dropped body. y=12"
@test deserialized_g.body isa Nothing
