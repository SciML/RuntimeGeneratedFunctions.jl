using RuntimeGeneratedFunctions, BenchmarkTools

const SUITE = BenchmarkGroup()

RuntimeGeneratedFunctions.init(@__MODULE__)

# =============================================================================
# Function generation
# =============================================================================

SUITE["generate"] = BenchmarkGroup()

SUITE["generate"]["scalar"] = @benchmarkable @RuntimeGeneratedFunction(:((x) -> x + 1))
SUITE["generate"]["closure_form"] = @benchmarkable @RuntimeGeneratedFunction(:((x, y) -> x * y + sin(x)))
SUITE["generate"]["multibody"] = @benchmarkable @RuntimeGeneratedFunction(
    :(
        function (du, u, p, t)
            du[1] = p[1] * u[1]
            du[2] = u[1] - u[2]
            return nothing
        end
    )
)

# =============================================================================
# Calls
# =============================================================================

SUITE["call"] = BenchmarkGroup()

f_scalar = @RuntimeGeneratedFunction(:((x) -> x^2 + 2x))
f_bin = @RuntimeGeneratedFunction(:((x, y) -> x * y + sin(x)))
f_ode = @RuntimeGeneratedFunction(
    :(
        function (du, u, p, t)
            du[1] = p[1] * u[1]
            du[2] = u[1] - u[2]
            return nothing
        end
    )
)

du = zeros(2)
u = [1.0, 2.0]
p = [0.5]

SUITE["call"]["scalar"] = @benchmarkable $f_scalar(3.0)
SUITE["call"]["binary"] = @benchmarkable $f_bin(1.5, 2.5)
SUITE["call"]["ode_iip"] = @benchmarkable $f_ode($du, $u, $p, 0.0)
