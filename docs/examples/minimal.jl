using Plugins, BenchmarkTools

mutable struct CounterPlugin <: Plugin
    count::UInt
    CounterPlugin() = new(0)
end
Plugins.symbol(::CounterPlugin) = :counter

function tick(me::CounterPlugin, app)
    me.count += 1
    return false
end

mutable struct App
    plugins::PluginStack
    App(plugins, hookfns) = new(PluginStack(plugins, hookfns))
end

function tickerop(app::App)
    tickhook = hooks(app).tick
    tickerop_kern(app, tickhook) # Using a function barrier to get ~7ns per hook activation
end

function tickerop_kern(app::App, tickhook)
    for i = 1:1e6
        tickhook()
    end
end

const app = app = App([CounterPlugin()], [tick])
@btime tickerop(app)
push!(app.plugins, CounterPlugin())
println("Total Tick Count: $(app.plugins[:counter].count)")