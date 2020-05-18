using Documenter, Plugins

makedocs(;
    modules=[Plugins],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/tisztamo/Plugins.jl/blob/{commit}{path}#L{line}",
    sitename="Plugins.jl",
    authors="Krisztián Schaffer",
    assets=String[],
)

deploydocs(;
    repo="github.com/tisztamo/Plugins.jl",
)
