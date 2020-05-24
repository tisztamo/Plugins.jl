module Plugins

import Base.length, Base.iterate, Base.get, Base.getindex

export PluginStack, Plugin, hooks, symbol, setup!, shutdown!

abstract type Plugin end

symbol(plugin::Plugin) = :nothing
setup!(plugin::Plugin, scheduler) = nothing
shutdown!(plugin::Plugin) = nothing

struct PluginStack
    plugins::Array{Plugin}
    cache::Dict{Symbol, Plugin}
    PluginStack(plugins) = new(plugins, Dict([(symbol(plugin), plugin) for plugin in plugins]))
end

Base.get(stack::PluginStack, key::Symbol, default=nothing) = get(stack.cache, key, default)
Base.getindex(stack::PluginStack, idx) = getindex(stack.plugins, idx)
Base.getindex(stack::PluginStack, key::Symbol) = get(stack, key)

struct HookList{TNext, THandler, TPlugin, TFramework}
    next::TNext
    handler::THandler
    plugin::TPlugin
    framework::TFramework
end

@inline function (hook::HookList)()::Bool
    if hook.handler(hook.plugin, hook.framework) !== false
        return hook.next()
    end
    return false
end

@inline function (hook::HookList)(event)::Bool
    if hook.handler(hook.plugin, hook.framework, event) !== false
        return hook.next(event)
    end
    return false
end

@inline function (hook::HookList)(p1, p2)::Bool
    if hook.handler(hook.plugin, hook.framework, p1, p2) !== false
        return hook.next(p1, p2)
    end
    return false
end

(hook::HookList{Nothing, T, Nothing, Nothing})() where T = true
(hook::HookList{Nothing, T, Nothing, Nothing})(a) where T = true
(hook::HookList{Nothing, T, Nothing, Nothing})(p1, p2) where T = true

length(l::HookList{Nothing, T, Nothing, Nothing}) where T = 0
length(l::HookList) = 1 + length(l.next)

iterate(l::HookList) = (l, l.next)
iterate(l::HookList, state) = isnothing(state) ? nothing : (state, state.next)
iterate(l::HookList, state::HookList{Nothing, T, Nothing, Nothing}) where T = nothing

function hooks(plugins::Array{TPlugins}, handler::THandler, framework::TFramework) where {TFramework, THandler, TPlugins}
    if length(plugins) == 0
        return HookList(nothing, nothing, nothing, nothing)
    end
    plugin = plugins[1]
    if length(methods(handler, (typeof(plugin), TFramework))) > 0 || length(methods(handler, (typeof(plugin), TFramework, Any))) > 0
        return HookList(hooks(plugins[2:end], handler, framework), handler, plugin, framework)
    end
    return hooks(plugins[2:end], handler, framework)
end
hooks(framework::TFramework, handler::THandler) where {THandler, TFramework} = hooks(framework.plugins, handler, framework)
hooks(stack::PluginStack, handler::THandler, framework::TFramework) where {TFramework, THandler} = hooks(stack.plugins, handler, framework)

function create_lifecyclehook(op::Function) 
    return (stack::PluginStack, framework) -> begin
        allok = true
        results = []
        for plugin in stack.plugins
            try
                push!(results, op(plugin, framework))
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

setup!(stack::PluginStack, framework) = setup_stack!(stack, framework)
shutdown!(stack::PluginStack, framework) = shutdown_stack!(stack, framework)

end # module
