using Test
using RuntimeGeneratedFunctions, BenchmarkTools
using Serialization

RuntimeGeneratedFunctions.init(@__MODULE__)

# Used by the tests that run a script in a fresh process.
proj = dirname(Base.active_project())
julia = joinpath(Sys.BINDIR, "julia")

function f(_du, _u, _p, _t)
    @inbounds _du[1] = _u[1]
    @inbounds _du[2] = _u[2]
    return nothing
end

ex1 = :(
    (_du, _u, _p, _t) -> begin
        @inbounds _du[1] = _u[1]
        @inbounds _du[2] = _u[2]
        nothing
    end
)

ex2 = :(
    function f(_du, _u, _p, _t)
        @inbounds _du[1] = _u[1]
        @inbounds _du[2] = _u[2]
        return nothing
    end
)

ex3 = :(
    function (_du::T, _u::Vector{E}, _p::P, _t::Any) where {T <: Vector, E, P}
        @inbounds _du[1] = _u[1]
        @inbounds _du[2] = _u[2]
        return nothing
    end
)

f0 = @RuntimeGeneratedFunction(:(() -> 42))
f1 = @RuntimeGeneratedFunction(ex1)
f2 = @RuntimeGeneratedFunction(ex2)
f3 = @RuntimeGeneratedFunction(ex3)

@test f0() === 42

@test f1 isa Function

function evaluate_through_function_interface(f::Function, value)
    return f(value)
end

@test evaluate_through_function_interface(@RuntimeGeneratedFunction(:(x -> x + 1)), 41) == 42

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

@test t1 ≈ t2 atol = 3.0e-8
@test t1 ≈ t3 atol = 3.0e-8
@test t1 ≈ t4 atol = 3.0e-8

function no_worldage()
    ex = :(
        function f(_du, _u, _p, _t)
            @inbounds _du[1] = _u[1]
            @inbounds _du[2] = _u[2]
            return nothing
        end
    )
    f1 = @RuntimeGeneratedFunction(ex)
    du = rand(2)
    u = rand(2)
    p = nothing
    t = nothing
    return f1(du, u, p, t)
end
@test no_worldage() === nothing

# Test show()
@test sprint(
    show, MIME"text/plain"(),
    @RuntimeGeneratedFunction(Base.remove_linenums!(:((x, y) -> x + y + 1)))
) ==
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
f_drop1,
    f_drop2 = let
    ex = Base.remove_linenums!(:(x -> x - 1))
    # Construct two identical RGFs here to test the cache deduplication code
    (
        drop_expr(@RuntimeGeneratedFunction(ex)),
        drop_expr(@RuntimeGeneratedFunction(ex)),
    )
end
GC.gc()
@test f_drop1(1) == 0
@test f_drop2(1) == 0

let
    script = joinpath(@__DIR__, "shared", "drop_expr_specializations.jl")
    trace_file, trace_io = mktemp()
    close(trace_io)
    try
        run(`$julia --startup-file=no --project=$proj --trace-compile=$trace_file $script`)
        specializations = count(eachline(trace_file)) do line
            startswith(
                line, "precompile(Tuple{typeof(RuntimeGeneratedFunctions.drop_expr),"
            )
        end
        @test specializations == 0
    finally
        rm(trace_file; force = true)
    end
end

# Test that threaded use works. Cache reads happen while the caller holds
# Julia's compiler lock, so a cache that blocks there deadlocks instead of
# failing; the subprocess needs a watchdog and more than one thread.
let
    script = joinpath(@__DIR__, "shared", "threaded_rgf.jl")
    proc = run(`$julia --startup-file=no --project=$proj --threads=8 $script`; wait = false)
    watchdog = Timer(_ -> process_running(proc) && kill(proc, Base.SIGKILL), 600)
    try
        wait(proc)
    finally
        close(watchdog)
    end
    @test success(proc)
end

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

@test_throws ErrorException @eval(
    module NotInitTest
    using RuntimeGeneratedFunctions
    # RuntimeGeneratedFunctions.init(@__MODULE__) # <-- missing
    f = @RuntimeGeneratedFunction(:(x -> x + y))
    end
)

ex = :(x -> (y -> x + y))
@test @RuntimeGeneratedFunction(ex)(2)(3) === 5

# used to stack overflow due to RGF calling itself, #146
f(x) = x + 1
ex = :(function(x); f(x); end)
@test @RuntimeGeneratedFunction(ex)(3) === 4

ex = :(x -> (f(y::Int)::Float64 = x + y; f))
@test @RuntimeGeneratedFunction(ex)(2)(3) === 5.0

ex = :(
    x -> function (y::Int)
        return x + y
    end
)
@test @RuntimeGeneratedFunction(ex)(2)(3) === 5

ex = :(
    x -> function f(y::Int)::UInt8
        return x + y
    end
)
@test @RuntimeGeneratedFunction(ex)(2)(3) === 0x05

ex = :(x -> sum(i^2 for i in 1:x))
@test @RuntimeGeneratedFunction(ex)(3) === 14

ex = :(x -> [2i for i in 1:x])
@test @RuntimeGeneratedFunction(ex)(3) == [2, 4, 6]

# Serialization

serialize_script = joinpath(@__DIR__, "shared", "serialize_rgf.jl")
buf = IOBuffer(read(`$julia --startup-file=no --project=$proj $serialize_script`))
deserialized_f, deserialized_g = deserialize(buf)
@test deserialized_f(11) == "Hi from a separate process. x=11"
@test deserialized_f.body isa Expr
@test deserialized_g(12) == "Serialization with dropped body. y=12"
@test deserialized_g.body isa Nothing

# deepcopy
ff = @RuntimeGeneratedFunction(:(x -> [x, x + 1]))
@test deepcopy(ff) == ff
@test deepcopy(ff) === ff
