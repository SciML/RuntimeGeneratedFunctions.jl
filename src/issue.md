**Describe the bug 🐞**

type data for function arguments is not retained in runtime generated functions:

```julia
julia> @RuntimeGeneratedFunction(:(f(a::AbstractArray) = sqrt.(a)))
RuntimeGeneratedFunction(#=in Main=#, #=using Main=#, :((a,)->begin
          #= REPL[23]:1 =#
          sqrt.(a)
      end))
```

**Expected behavior**

Expected the runtime generated function to look like this:

```julia
RuntimeGeneratedFunction(#=in Main=#, #=using Main=#, :((a::AbstractArray,)->begin
          #= REPL[23]:1 =#
          sqrt.(a)
      end))
```

with the type of `a` included in the function definition.
**Minimal Reproducible Example 👇**

```julia
julia> @RuntimeGeneratedFunction(:(f(a::AbstractArray) = sqrt.(a)))
RuntimeGeneratedFunction(#=in Main=#, #=using Main=#, :((a,)->begin
          #= REPL[23]:1 =#
          sqrt.(a)
      end))
```

Without MRE, we would only be able to help you to a limited extent, and attention to the issue would be limited. to know more about MRE refer to [wikipedia](https://en.wikipedia.org/wiki/Minimal_reproducible_example) and [stackoverflow](https://stackoverflow.com/help/minimal-reproducible-example).

```julia

```

**Error & Stacktrace ⚠️**

```julia

```

**Environment (please complete the following information):**

- Output of `using Pkg; Pkg.status()`

```julia
julia> using Pkg; Pkg.status()
Status `C:\Users\seatt\.julia\environments\v1.10\Project.toml`
  [6e4b80f9] BenchmarkTools v1.5.0
  [a8cc5b0e] Crayons v4.1.1
  [5fb14364] OhMyREPL v0.5.28
  [295af30f] Revise v3.5.18
```

- Output of `using Pkg; Pkg.status(; mode = PKGMODE_MANIFEST)`

```julia
julia> Pkg; Pkg.status(; mode = PKGMODE_MANIFEST)
Status `C:\Users\seatt\.julia\environments\v1.10\Manifest.toml`
  [6e4b80f9] BenchmarkTools v1.5.0
  [da1fd8a2] CodeTracking v1.3.6
  [a8cc5b0e] Crayons v4.1.1
  [1019f520] JLFzf v0.1.7
  [692b3bcd] JLLWrappers v1.5.0
  [682c06a0] JSON v0.21.4
  [aa1ae85d] JuliaInterpreter v0.9.34
  [70703baa] JuliaSyntax v0.4.9
  [6f1432cf] LoweredCodeUtils v3.0.1
  [5fb14364] OhMyREPL v0.5.28
  [bac558e1] OrderedCollections v1.6.3
  [69de0a69] Parsers v2.8.1
  [b98c9c47] Pipe v1.3.0
  [aea7be01] PrecompileTools v1.2.1
  [21216c6a] Preferences v1.4.3
  [ae029012] Requires v1.3.0
  [295af30f] Revise v3.5.18
⌅ [214eeab7] fzf_jll v0.43.0+0
  [0dad84c5] ArgTools v1.1.1
  [56f22d72] Artifacts
  [2a0f44e3] Base64
  [ade2ca70] Dates
  [8ba89e20] Distributed
  [f43a241f] Downloads v1.6.0
  [7b1f6079] FileWatching
  [b77e0a4c] InteractiveUtils
  [b27032c2] LibCURL v0.6.4
  [76f85450] LibGit2
  [8f399da3] Libdl
  [37e2e46d] LinearAlgebra
  [56ddb016] Logging
  [d6f4376e] Markdown
  [a63ad114] Mmap
  [ca575930] NetworkOptions v1.2.0
  [44cfe95a] Pkg v1.10.0
  [de0858da] Printf
  [9abbd945] Profile
  [3fa0cd96] REPL
  [9a3f8284] Random
  [ea8e919c] SHA v0.7.0
  [9e88b42a] Serialization
  [6462fe0b] Sockets
  [2f01184e] SparseArrays v1.10.0
  [10745b16] Statistics v1.10.0
  [fa267f1f] TOML v1.0.3
  [a4e569a6] Tar v1.10.0
  [cf7118a7] UUIDs
  [4ec0a83e] Unicode
  [e66e0078] CompilerSupportLibraries_jll v1.1.1+0
  [deac9b47] LibCURL_jll v8.4.0+0
  [e37daf67] LibGit2_jll v1.6.4+0
  [29816b5a] LibSSH2_jll v1.11.0+1
  [c8ffd9c3] MbedTLS_jll v2.28.2+1
  [14a3606d] MozillaCACerts_jll v2023.1.10
  [4536629a] OpenBLAS_jll v0.3.23+4
  [bea87d4a] SuiteSparse_jll v7.2.1+1
  [83775a58] Zlib_jll v1.2.13+1
  [8e850b90] libblastrampoline_jll v5.8.0+1
  [8e850ede] nghttp2_jll v1.52.0+1
  [3f19e933] p7zip_jll v17.4.0+2
Info Packages marked with ⌅ have new versions available but compatibility constraints restrict them from upgrading. To see why use `status --outdated -m`

```

- Output of `versioninfo()`

```julia
julia> versioninfo()
Julia Version 1.10.4
Commit 48d4fd4843 (2024-06-04 10:41 UTC)
Build Info:
  Official https://julialang.org/ release
Platform Info:
  OS: Windows (x86_64-w64-mingw32)
  CPU: 32 × AMD Ryzen 9 7950X 16-Core Processor
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-15.0.7 (ORCJIT, znver3)
Threads: 16 default, 0 interactive, 8 GC (on 32 virtual cores)
Environment:
  JULIA_EDITOR = code.cmd
  JULIA_NUM_THREADS = 16
```

**Additional context**
I noticed this problem when generating runtime functions for FastDifferentiation.jl. I expected the runtime functions to accept a single array argument but instead they accept any number, and apparently type, of arguments and ignore all but the first. This could be confusing to an end user of my package.

```
julia> @RuntimeGeneratedFunction(:(f(a::AbstractArray) = sqrt.(a)))
RuntimeGeneratedFunction(#=in Main=#, #=using Main=#, :((a,)->begin
          #= REPL[27]:1 =#
          sqrt.(a)
      end))

julia> h1 = ans
RuntimeGeneratedFunction(#=in Main=#, #=using Main=#, :((a,)->begin
          #= REPL[27]:1 =#
          sqrt.(a)
      end))

julia> h1(1,2)
1.0

julia> h1(1,2,3,4,5)
1.0

julia> h1([1])
1-element Vector{Float64}:
 1.0
```

Don't know if this behavior was intentional or not, assumed it was a bug. If it's not feel free to move this to the feature request category.
