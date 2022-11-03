using RuntimeGeneratedFunctions
using Documenter

makedocs(sitename = "RuntimeGeneratedFunctions.jl",
         authors = "Chris Rackauckas",
         modules = [RuntimeGeneratedFunctions],
         clean = true, doctest = false,
         strict = [
             :doctest,
             :linkcheck,
             :parse_error,
             :example_block,
             # Other available options are
             # :autodocs_block, :cross_references, :docs_block, :eval_block, :example_block, :footnote, :meta_block, :missing_docs, :setup_block
         ],
         format = Documenter.HTML(analytics = "UA-90474609-3",
                                  assets = ["assets/favicon.ico"],
                                  canonical = "https://docs.sciml.ai/RuntimeGeneratedFunctions/stable/"),
         pages = [
             "RuntimeGeneratedFunctions.jl: Efficient Staged Compilation" => "index.md",
         ])

deploydocs(;
           repo = "github.com/SciML/RuntimeGeneratedFunctions.jl")
