# # Getting Started
# ## Installation
# The package is registered, so simply: `julia> using Pkg; Pkg.add("Plugins")`

# ## Your first plugin

# This will be a simple performance counter that calculates the rolling average of elapsed time
# between calls to the `tick()` hook.

using Plugins

mutable struct PerfPlugin <: Plugin
    last_call_ts::UInt64
    avg_elapsed::Float64
    PerfPlugin() = new(time_ns(), 0)
end

# When the `tick()` hook is called, it calculates the difference to the stored timestamp of the last call, and updates the exponential moving average.

const alpha = 0.99

function tick(me::PerfPlugin, shared_state)
    ts = time_ns()
    diff = ts - me.last_call_ts
    me.last_call_ts = ts
    me.avg_elapsed = alpha * me.avg_elapsed + (1 - alpha) * diff
end

# Now let's create the base system