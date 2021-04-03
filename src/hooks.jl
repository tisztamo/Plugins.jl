"""
    HookList{TNext, THandler, TPlugin}

Provides fast, inlinable call to the implementations of a specific hook.

You can get a HookList by calling `hooklist()` directly, or using `hooks()`.

The `HookList` can be called with arbitrary number of extra arguments. If any of the
plugins referenced in the list fails to handle the extra arguments, the call will raise a `MethodError`
"""
struct HookList{TNext, THandler, TPlugin}
    next::TNext
    handler::THandler
    plugin::TPlugin
end

HookListTerminal = HookList{Nothing, Nothing, Nothing}

@inline function (hook::HookList)(args...)::Bool
    if hook.handler(hook.plugin, args...) !== true
        return hook.next(args...)
    end
    return true
end

(hook::HookListTerminal)(::Vararg{Any}) = false

length(l::HookListTerminal) = 0
length(l::HookList) = 1 + length(l.next)

iterate(l::HookList) = (l, l.next)
iterate(::HookList, state) = isnothing(state) ? nothing : (state, state.next)
iterate(::HookList, ::HookListTerminal) = nothing

"""
    function hooklist(plugins, hookfn)

Create a HookList which allows fast, inlinable call to the merged implementations of `hookfn`
by the given plugins.

A plugin of type `TPlugin` found in plugins will be referenced in the resulting HookList if there is a method
that matches the following signature: `hookfn(::TPlugin, ...)`
"""
function hooklist(plugins, hookfn)
    if length(plugins) == 0
        return HookListTerminal(nothing, nothing, nothing)
    end
    plugin = plugins[1]
    if length(methods(hookfn, (typeof(plugin), Vararg{Any}))) > 0
        return HookList(hooklist(plugins[2:end], hookfn), hookfn, plugin)
    end
    return hooklist(plugins[2:end], hookfn)
end
hooklist(stack::PluginStack, hookfn) = hooklist(stack.plugins, hookfn)

"""
    hooks(app)
    hooks(pluginstack::PluginStack)

Create or get a hook cache for `stack`.

The first form can be used when `pluginstack` is stored in `app.plugins` (the recommended pattern).

When this function is called first time on a `PluginStack`, the hooks cache will be created by calling
`hook_cache()`, and stored in `pluginstack` for quick access later.
"""
function hooks end

@inline hooks(app) = hooks(app.plugins)
@inline hooks(stack::PluginStack) = stack.hookcache

function rebuild_cache!(stack::PluginStack)
    stack.symbolcache = symbolcache(stack.plugins)
    stack.hookcache = hook_cache(stack)
end

"""
    hook_cache(stack::PluginStack, hookfns)
    hook_cache(plugins, hookfns)

Create a cache of `HookList`s for a PluginStack or from lists of plugins and hook functions.

Returns a NamedTuple with an entry for every handler.

# Examples

```julia
cache = hook_cache([Plugin1(), Plugin2()], [hook1, hook2])
cache.hook1()
```
"""
function hook_cache(plugins, hookfns)
    return (;(nameof(hook) => hooklist(plugins, hook) for hook in hookfns)...)
end
hook_cache(stack::PluginStack) = hook_cache(stack.plugins, stack.hookfns)

function create_lifecyclehook(op::Function)
    return (stack::PluginStack, data...) -> begin # TODO We loose the name of op, which may be needed for error reporting
        allok = true
        results = []
        for plugin in reverse(stack.plugins)
            try
                pushfirst!(results, op(plugin, data...))
            catch e
                allok = false
                pushfirst!(results, (e, catch_backtrace()))
            end
        end
        return (allok = allok, results = results)
    end
end
