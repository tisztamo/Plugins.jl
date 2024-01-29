using Literate, Documenter, Documenter.Remotes, Plugins

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
    repo = Documenter.Remotes.GitHub("tisztamo", "Plugins.jl"),
    sitename="Plugins.jl",
    authors="Krisztián Schaffer"
)

deploydocs(;
    repo = GitHub("tisztamo", "Plugins.jl"),
    devbranch = "main"
)
