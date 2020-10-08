# # Getting Started

# ## Motivation

# Let's say you are writing a lib which performs some work in a loop quickly (up to several million times
# per second). You need to allow your users to monitor this loop, but the requirements vary: One user just wants to
# count the total number of cycles, another wants to measure the performance and write some metrics to a file regularly, etc.
# The only requirement that everybody has is maximum performance.
#
# Maybe you also have an item on your wishlist: To allow your less techie users to configure the monitoring without
# coding. Sometimes you even dream of reconfiguring the monitoring while the app is running... 

# ## Installation
# The package is registered, so simply: `julia> using Pkg; Pkg.add("Plugins")`. ([repo](https://github.com/tisztamo/Plugins.jl))

# ## Your first and second plugins
#
# The first one simply counts the calls to the `tick()` hook.

using Plugins, Printf, Test

mutable struct CounterPlugin <: Plugin
    count::UInt
    CounterPlugin() = new(0)
end

Plugins.symbol(::CounterPlugin) = :counter # For access from the outside / from other plugins

function tick(me::CounterPlugin, app)
    me.count += 1
end;

# The second will measure the frequency of `tick()` calls:

mutable struct PerfPlugin <: Plugin
    last_call_ts::UInt64
    avg_elapsed::Float32
    PerfPlugin() = new(time_ns(), 0)
end

Plugins.symbol(::PerfPlugin) = :perf

tickfreq(me::PerfPlugin) = 1e9 / me.avg_elapsed;

# When the `tick()` hook is called, it calculates the time difference to the stored timestamp
# of the last call, and updates the exponential moving average:

const alpha = 1.0f-3

function tick(me::PerfPlugin, app)
    ts = time_ns()
    diff = ts - me.last_call_ts
    me.last_call_ts = ts
    me.avg_elapsed = alpha * Float32(diff) + (1.0f0 - alpha) * me.avg_elapsed 
end;

# ## The application

# Now let's create the base system. Its state holds the plugins and a counter (just to cross-check the `CounterPlugin`):

mutable struct App
    plugins::PluginStack
    tick_counter::UInt
    App(plugins, hookfns) = new(PluginStack(plugins, hookfns), 0)
end

# There is a single operation on the app, which increments the `tick_counter` in a cycle and calls the `tick()` hook:

function tickerop(app::App)
    tickhook = hooks(app).tick
    tickerop_kern(app, tickhook) # Using a function barrier to get ~5ns per hook activation
end

function tickerop_kern(app::App, tickhook)
    for i = 1:1e6
        app.tick_counter += 1
        tickhook(app) # Fo simplicity we give the whole app to plugins as 'shared state'
    end
end;

# ## Running it

# The last step is to initialize the app, call the operation, and read out the performance measurement from the plugins:

app = App([CounterPlugin(), PerfPlugin()], [tick])
tickerop(app)

@test app.plugins[:counter].count == app.tick_counter
println("Tick count: $(app.plugins[:counter].count)")
println("Average cycle time: $(@sprintf("%.2f", app.plugins[:perf].avg_elapsed)) nanoseconds, frequency: $(@sprintf("%.2f", tickfreq(app.plugins[:perf]) / 1e6)) MHz")

# *That was on the CI. On an i7 7700K I typically get around 19.95ns / 50.14 MHz.* There is no overhead compared to a direct call
# of the manually merged `tick()` methods.
#
# You can find this example under `docs/examples/gettingstarted.jl` if you check out the [repo](https://github.com/tisztamo/Plugins.jl).