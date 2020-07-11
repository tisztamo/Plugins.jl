module Plugins

import Base.length, Base.iterate, Base.get, Base.getindex

export PluginStack, Plugin, hooks, hooklist, hook_cache, setup!, shutdown!

"""
    abstract type Plugin

Provides default implementations of lifecycle hooks.
"""
abstract type Plugin end

"""
    symbol(plugin)

Return the unique Symbol of this plugin if it exports an API to other plugins.
"""
symbol(plugin::Plugin) = :nothing

"""
    setup!(plugin, sharedstate)

Initialize the plugin with the given shared state.

This lifecycle hook should be called when the application loads a plugin. Plugins.jl does not (yet) helps with this,
application developers should do it manually, right after the PluginStack was created, before the hook_cache() call.
"""
setup!(plugin::Plugin, sharedstate) = nothing

"""
    shutdown!(plugin, sharedstate)

Shut down the plugin.

This lifecycle hook should be called when the application unloads a plugin, e.g. before the application exits.
Plugins.jl does not (yet) helps with this, application developers should do it manually.
"""
shutdown!(plugin::Plugin, sharedstate) = nothing

"""
    PluginStack(plugins, hookfns = [])

Manages the plugins loaded into an application.

It provides fast access to the plugins by symbol, e.g. `pluginstack[:logger]`. Also implements the iteration interface.

The pluginstack is created from a list of plugins, and optionally a list of hook functions. If hook functions are provided,
the `hooks()`` function can be called to

"""
mutable struct PluginStack
    plugins::Array{Plugin}
    hookfns
    symbolcache::Dict{Symbol, Plugin}
    hookcache::Union{NamedTuple, Nothing}
    PluginStack(plugins, hookfns = []) = new(plugins, hookfns, Dict([(symbol(plugin), plugin) for plugin in plugins]), nothing)
end

Base.length(stack::PluginStack) = length(stack.plugins)
Base.iterate(stack::PluginStack) = iterate(stack.plugins)
Base.iterate(stack::PluginStack, state) = iterate(stack.plugins, state)

Base.get(stack::PluginStack, key::Symbol, default=nothing) = get(stack.symbolcache, key, default)
Base.getindex(stack::PluginStack, idx) = getindex(stack.plugins, idx)
Base.getindex(stack::PluginStack, key::Symbol) = get(stack, key)

"""
    HookList{TNext, THandler, TPlugin, TSharedState}

Provides fast, inlinable call to the implementations of a specific hook.

You can get a HookList by calling `hooklist()` directly, or using `hooks()`.

The `HookList` can be called with a `::TSharedState` and an arbitrary number of extra arguments. If any of the
plugins referenced in the list fails to handle the extra arguments, the call will raise a `MethodError`
"""
struct HookList{TNext, THandler, TPlugin, TSharedState}
    next::TNext
    handler::THandler
    plugin::TPlugin
    sharedstate::TSharedState
end

HookListTerminal = HookList{Nothing, Nothing, Nothing, Nothing}

@inline function (hook::HookList)(params...)::Bool
    if hook.handler(hook.plugin, hook.sharedstate, params...) !== true
        return hook.next(params...)
    end
    return true
end

(hook::HookListTerminal)(::Vararg{Any}) = false

length(l::HookListTerminal) = 0
length(l::HookList) = 1 + length(l.next)

iterate(l::HookList) = (l, l.next)
iterate(l::HookList, state) = isnothing(state) ? nothing : (state, state.next)
iterate(l::HookList, state::HookListTerminal) = nothing

"""
    function hooklist(plugins, hookfn, sharedstate::TSharedState) where {TSharedState}

Create a HookList which allows fast, inlinable call to the merged implementations of `hookfn` for `TSharedState`
by the given plugins.

A plugin of type `TPlugin` found in plugins will be referenced in the resulting HookList if there is a method
with the following signature: `hookfn(::TPlugin, ::TSharedState, ...)`
"""
function hooklist(plugins, hookfn, sharedstate::TSharedState) where {TSharedState}
    if length(plugins) == 0
        return HookListTerminal(nothing, nothing, nothing, nothing)
    end
    plugin = plugins[1]
    if length(methods(hookfn, (typeof(plugin), TSharedState, Vararg{Any}))) > 0
        return HookList(hooklist(plugins[2:end], hookfn, sharedstate), hookfn, plugin, sharedstate)
    end
    return hooklist(plugins[2:end], hookfn, sharedstate)
end
hooklist(sharedstate, hookfn) = hooklist(sharedstate.plugins, hookfn, sharedstate)
hooklist(stack::PluginStack, hookfn, sharedstate) = hooklist(stack.plugins, hookfn, sharedstate)

"""
    hooks(sharedstate, rebuild = false)
    hooks(pluginstack::PluginStack, sharedstate, rebuild = false)

Create or get a hook cache for `stack` and `sharedstate`.

The first form can be used when `pluginstack` is stored in `sharedstate.plugins` (the recommended pattern).

When this function is called first time on a `PluginStack`, the hooks cache will be created by calling
`hook_cache()`, and stored in `stack` for quick access later.

The hook cache will be rebuilt if the `rebuild` argument is true.
"""
function hooks end

function hooks(stack::PluginStack, sharedstate, rebuild::Bool = false)
    if isnothing(stack.hookcache) || rebuild
        stack.hookcache = hook_cache(stack.hookfns, sharedstate)
    end
    return stack.hookcache
end

hooks(sharedstate, rebuild::Bool = false) = hooks(sharedstate.plugins, sharedstate, rebuild)

"""
    hook_cache(hookfns, sharedstate)

Create a cache of `HookList`s from the list of hook functions.

Returns a NamedTuple with an entry for every handler.

# Examples

```julia
cache = hook_cache([hook1, hook2], app)
cache.hook1()
```
    
"""
function hook_cache(handlers, sharedstate)
    return (;(nameof(hook) => hooklist(sharedstate, hook) for hook in handlers)...)
end

function create_lifecyclehook(op::Function) 
    return (stack::PluginStack, data) -> begin
        allok = true
        results = []
        for plugin in stack.plugins
            try
                push!(results, op(plugin, data))
            catch e
                allok = false
                push!(results, e)
            end
        end
        return (allok = allok, results = results)
    end
end

setup_stack! = create_lifecyclehook(setup!)
shutdown_stack! = create_lifecyclehook(shutdown!)

setup!(stack::PluginStack, sharedstate) = setup_stack!(stack, sharedstate)
shutdown!(stack::PluginStack, sharedstate) = shutdown_stack!(stack, sharedstate)

end # module
