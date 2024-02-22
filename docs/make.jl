using RuntimeGeneratedFunctions
using Documenter

cp("./docs/Manifest.toml", "./docs/src/assets/Manifest.toml", force = true)
cp("./docs/Project.toml", "./docs/src/assets/Project.toml", force = true)

makedocs(sitename = "RuntimeGeneratedFunctions.jl",
    authors = "Chris Rackauckas",
    modules = [RuntimeGeneratedFunctions],
    clean = true, doctest = false, linkcheck = true,
    format = Documenter.HTML(assets = ["assets/favicon.ico"],
        canonical = "https://docs.sciml.ai/RuntimeGeneratedFunctions/stable/"),
    pages = [
        "RuntimeGeneratedFunctions.jl: Efficient Staged Compilation" => "index.md",
        "API" => "api.md"
    ])

deploydocs(;
    repo = "github.com/SciML/RuntimeGeneratedFunctions.jl")
