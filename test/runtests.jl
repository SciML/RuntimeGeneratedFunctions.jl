using RuntimeGeneratedFunctions, BenchmarkTools
using Test

RuntimeGeneratedFunctions.init(@__MODULE__)

function f(_du,_u,_p,_t)
    @inbounds _du[1] = _u[1]
    @inbounds _du[2] = _u[2]
    nothing
end

ex1 = :((_du,_u,_p,_t) -> begin
    @inbounds _du[1] = _u[1]
    @inbounds _du[2] = _u[2]
    nothing
end)

ex2 = :(function f(_du,_u,_p,_t)
    @inbounds _du[1] = _u[1]
    @inbounds _du[2] = _u[2]
    nothing
end)

ex3 = :(function (_du::T,_u::Vector{E},_p::P,_t::Any) where {T<:Vector,E,P}
    @inbounds _du[1] = _u[1]
    @inbounds _du[2] = _u[2]
    nothing
end)

f1 = RuntimeGeneratedFunction(@__MODULE__, ex1)
f2 = RuntimeGeneratedFunction(@__MODULE__, ex2)
f3 = RuntimeGeneratedFunction(@__MODULE__, ex3)

@test f1 isa Function

du = rand(2)
u = rand(2)
p = nothing
t = nothing

@test f1(du,u,p,t) === nothing
du == u
du = rand(2)
f2(du,u,p,t)
@test du == u
du = rand(2)
@test f3(du,u,p,t) === nothing
du == u

t1 = @belapsed $f($du,$u,$p,$t)
t2 = @belapsed $f1($du,$u,$p,$t)
t3 = @belapsed $f2($du,$u,$p,$t)
t4 = @belapsed $f3($du,$u,$p,$t)

@test t1 ≈ t2 atol = 3e-9
@test t1 ≈ t3 atol = 3e-9
@test t1 ≈ t4 atol = 3e-9

function no_worldage()
    ex = :(function f(_du,_u,_p,_t)
        @inbounds _du[1] = _u[1]
        @inbounds _du[2] = _u[2]
        nothing
    end)
    f1 = RuntimeGeneratedFunction(@__MODULE__, ex)
    du = rand(2)
    u = rand(2)
    p = nothing
    t = nothing
    f1(du,u,p,t)
end
@test no_worldage() === nothing

# Test show()
@test sprint(show, RuntimeGeneratedFunction(@__MODULE__, Base.remove_linenums!(:((x,y)->x+y+1)))) ==
     """
     RuntimeGeneratedFunction(#=in $(@__MODULE__)=#, :((x, y)->begin
               x + y + 1
           end))"""

# Test with precompilation
push!(LOAD_PATH, joinpath(@__DIR__, "precomp"))
using RGFPrecompTest

@test RGFPrecompTest.f(1,2) == 3

# Test that RuntimeGeneratedFunction with identical body expressions (but
# allocated separately) don't clobber each other when one is GC'd.
f_gc = RuntimeGeneratedFunction(@__MODULE__, Base.remove_linenums!(:((x,y)->x+y+100001)))
let
    RuntimeGeneratedFunction(@__MODULE__, Base.remove_linenums!(:((x,y)->x+y+100001)))
end
GC.gc()
@test f_gc(1,-1) == 100001

# Test that threaded use works
tasks = []
for k=1:4
    let k=k
        t = Threads.@spawn begin
            r = Bool[]
            for i=1:100
                f = RuntimeGeneratedFunction(@__MODULE__, Base.remove_linenums!(:((x,y)->x+y+$i*$k)))
                x = 1; y = 2;
                push!(r, f(x,y) == x + y + i*k)
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

    y = 40
    f = RuntimeGeneratedFunction(@__MODULE__, :(x->x+y))
end

@test GlobalsTest.f(2) == 42

@test_throws ErrorException @eval(module NotInitTest
    using RuntimeGeneratedFunctions
    # RuntimeGeneratedFunctions.init(@__MODULE__) # <-- missing
    f = RuntimeGeneratedFunction(@__MODULE__, :(x->x+y))
end)
