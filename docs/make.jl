using Literate, Documenter, Plugins

# Generating to docs/src, was unable to load pages from a different directory
Literate.markdown("docs/src/gettingstarted.jl", "docs/src/"; documenter = true)

makedocs(;
    modules=[Plugins],
    format=Documenter.HTML(),
    pages=[
        "index.md",
        "gettingstarted.md",
        "reference.md",
    ],
    repo="https://github.com/tisztamo/Plugins.jl/blob/{commit}{path}#L{line}",
    sitename="Plugins.jl",
    authors="Krisztián Schaffer",
    assets=String[],
)

deploydocs(;
    repo="github.com/tisztamo/Plugins.jl",
)
