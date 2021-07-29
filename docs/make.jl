using Literate, Documenter, Plugins

# Generating to docs/src, was unable to load pages from a different directory
Literate.markdown("docs/examples/gettingstarted.jl", "docs/src/"; documenter = true)

makedocs(;
    modules=[Plugins],
    format=Documenter.HTML(
        assets = ["assets/favicon.ico"]
    ),
    pages=[
        "index.md",
        "tutorial.md",
        "features.md",
        "guide.md",
        "repo.md",
        "reference.md",
    ],
    repo="https://github.com/tisztamo/Plugins.jl/blob/{commit}{path}#L{line}",
    sitename="Plugins.jl",
    authors="Krisztián Schaffer",
    assets=String[],
)

deploydocs(;
    repo="github.com/tisztamo/Plugins.jl",
    devbranch = "main"
)
