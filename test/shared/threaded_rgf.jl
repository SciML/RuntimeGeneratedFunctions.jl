# Construct and call RuntimeGeneratedFunctions from several threads at once.
# Run as a subprocess by core_tests.jl because the failure mode it guards
# against is a hang rather than a wrong answer, and it needs more than one
# thread to show up.

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

tasks = map(1:max(4, Threads.nthreads())) do k
    Threads.@spawn begin
        for i in 1:100
            f = @RuntimeGeneratedFunction(
                Base.remove_linenums!(:((x, y) -> x + y + $i * $k))
            )
            f(1, 2) == 3 + i * k || error("wrong result for i=$i, k=$k")
        end
    end
end
foreach(fetch, tasks)
