using NAssets
using Documenter

DocMeta.setdocmeta!(NAssets, :DocTestSetup, :(using NAssets); recursive=true)

makedocs(;
    modules=[NAssets],
    authors="mperhez <marcoph.org> and contributors",
    repo="https://github.com/mperhez/NAssets.jl/blob/{commit}{path}#{line}",
    sitename="NAssets.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://mperhez.github.io/NAssets.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/mperhez/NAssets.jl",
)