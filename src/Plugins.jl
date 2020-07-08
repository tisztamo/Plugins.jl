module Plugins

import Base.length, Base.iterate, Base.get, Base.getindex

export PluginStack, Plugin, hooks, symbol, hook_cache, setup!, shutdown!

abstract type Plugin end

symbol(plugin::Plugin) = :nothing
setup!(plugin::Plugin, x...) = nothing
shutdown!(plugin::Plugin, x...) = nothing

struct PluginStack
    plugins::Array{Plugin}
    cache::Dict{Symbol, Plugin}
    PluginStack(plugins) = new(plugins, Dict([(symbol(plugin), plugin) for plugin in plugins]))
end

Base.length(stack::PluginStack) = length(stack.plugins)
Base.iterate(stack::PluginStack) = iterate(stack.plugins)
Base.iterate(stack::PluginStack, state) = iterate(stack.plugins, state)

Base.get(stack::PluginStack, key::Symbol, default=nothing) = get(stack.cache, key, default)
Base.getindex(stack::PluginStack, idx) = getindex(stack.plugins, idx)
Base.getindex(stack::PluginStack, key::Symbol) = get(stack, key)

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

function hooks(plugins::AbstractArray{TPlugins}, handler::THandler, sharedstate::TSharedState) where {TSharedState, THandler, TPlugins}
    if length(plugins) == 0
        return HookListTerminal(nothing, nothing, nothing, nothing)
    end
    plugin = plugins[1]
    if length(methods(handler, (typeof(plugin), TSharedState, Vararg{Any}))) > 0
        return HookList(hooks(plugins[2:end], handler, sharedstate), handler, plugin, sharedstate)
    end
    return hooks(plugins[2:end], handler, sharedstate)
end
hooks(sharedstate, handler) = hooks(sharedstate.plugins, handler, sharedstate)
hooks(stack::PluginStack, handler::THandler, sharedstate::TSharedState) where {TSharedState, THandler} = hooks(stack.plugins, handler, sharedstate)

"""
    hook_cache(handlers, sharedstate)

Create a cache of `HookList`s from the list of handler functions.

Returns a NamedTuple with an entry for every handler.

# Examples

```julia
cache = hook_cache([hook1, hook2], app)
cache.hook1()
```
    
"""
function hook_cache(handlers, sharedstate)
    return (;(nameof(hook) => hooks(sharedstate, hook) for hook in handlers)...)
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
