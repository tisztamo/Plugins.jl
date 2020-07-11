# # Getting Started
# ## Installation
# The package is registered, so simply: `julia> using Pkg; Pkg.add("Plugins")`. ([repo](https://github.com/tisztamo/Plugins.jl))

# ## Your first plugin

# This will be a simple performance counter to measure the frequency of `tick()` calls.
# It calculates the rolling average of elapsed time between calls to the `tick()` hook:

using Plugins, Printf

mutable struct PerfPlugin <: Plugin
    last_call_ts::UInt64
    avg_elapsed::Float32
    PerfPlugin() = new(time_ns(), 0)
end

Plugins.symbol(::PerfPlugin) = :perf

tickfreq(me::PerfPlugin) = 1e9 / me.avg_elapsed;

# When the `tick()` hook is called, the plugin calculates the time difference to the stored timestamp
# of the last call, and updates the exponential moving average:

const alpha = 1.0f-3

function tick(me::PerfPlugin, app)
    ts = time_ns()
    diff = ts - me.last_call_ts
    me.last_call_ts = ts
    me.avg_elapsed = alpha * Float32(diff) + (1.0f0 - alpha) * me.avg_elapsed 
end;

# ## The application

# Now let's create the base system. Its state holds the plugins and a counter:

mutable struct App
    plugins::PluginStack
    tick_counter::UInt
    App(plugins, hookfns) = new(PluginStack(plugins, hookfns), 0)
end

# There is a single operation on the app, which increments a counter in a cycle and calls the `tick()` hook:

function tickerop(app::App)
    tickhook = hooks(app).tick
    tickerop_kern(app, tickhook) # Using a function barrier to get ~5ns per plugin activation
end

function tickerop_kern(app::App, tickhook)
    for i = 1:1e6
        app.tick_counter += 1
        tickhook()
    end
end;

# ## Running it

# The last step is to initialize the app, call the operation, and read out the performance measurement from the plugin:

app = App([PerfPlugin()], [tick])
tickerop(app)
println("Average cycle time: $(@sprintf("%.2f", app.plugins[:perf].avg_elapsed)) nanoseconds, frequency: $(@sprintf("%.2f", tickfreq(app.plugins[:perf]) / 1e6)) MHz")

# *That was on the CI. On an i7 7700K I typically get around 19.80ns / 50.52 MHz.* There is no overhead compared to a direct call
# of the `tick(::PerfPlugin, ::Any)` method.
#
# You can find this example under `docs/examples/gettingstarted.jl` if you check out the [repo](https://github.com/tisztamo/Plugins.jl).