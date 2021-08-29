module Plugins

import Base.length, Base.iterate, Base.get, Base.getindex

export PluginStack, Plugin,
    hooks, hooklist, hook_cache,
    call_optional,
    customtype

"""
    abstract type Plugin

Provides default implementations of lifecycle hooks.
"""
abstract type Plugin end

"""
    PluginStack(plugins, hookfns = [])

Manages the plugins loaded into an application.

It provides fast access to the plugins by symbol, e.g. `pluginstack[:logger]`. Collection methods and iteration interface are implemented.

The pluginstack is created from a list of plugins, and optionally a list of hook functions. If hook functions are provided,
the `hooks()`` function can be called to

"""
mutable struct PluginStack
    plugins::Array{Plugin}
    hookfns
    symbolcache::Dict{Symbol, Plugin}
    hookcache::Union{NamedTuple, Nothing}
    PluginStack(plugintypes, hookfns = []; options...) = begin
        plugins = instantiate(plugintypes; options...)
        stack = new(plugins, hookfns, symbolcache(plugins), nothing)
        rebuild_cache!(stack)
        return stack
    end
end

symbolcache(plugins) = Dict([(symbol(plugin), plugin) for plugin in plugins])

Base.push!(stack::PluginStack, items...) = update!(stack, Base.push!, items...)
Base.pushfirst!(stack::PluginStack, items...) = update!(stack, Base.pushfirst!, items...)
Base.pop!(stack::PluginStack, items...) = update!(stack, Base.pop!, items...)
Base.popfirst!(stack::PluginStack, items...) = update!(stack, Base.popfirst!, items...)
Base.empty!(stack::PluginStack, items...) = update!(stack, Base.empty!, items...)

function update!(stack::PluginStack, op, args...)
    retval = op(stack.plugins, args...)
    rebuild_cache!(stack)
    return retval
end

Base.isempty(stack::PluginStack) = Base.isempty(stack.plugins)
Base.length(stack::PluginStack) = length(stack.plugins)
Base.iterate(stack::PluginStack) = iterate(stack.plugins)
Base.iterate(stack::PluginStack, state) = iterate(stack.plugins, state)

Base.get(stack::PluginStack, key::Symbol, default=nothing) = get(stack.symbolcache, key, default)
Base.getindex(stack::PluginStack, idx) = getindex(stack.plugins, idx)
Base.getindex(stack::PluginStack, key::Symbol) = get(stack, key)
Base.setindex!(stack::PluginStack, args...) = update!(stack, setindex!, args...)

include("hooks.jl")
include("deps.jl")
include("assembled_types.jl")
include("stages.jl")
include("lifecycle.jl")

end # module
