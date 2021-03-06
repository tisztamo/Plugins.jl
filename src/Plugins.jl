module Plugins

import Base.length, Base.iterate, Base.get, Base.getindex

export PluginStack, Plugin,
    hooks, hooklist, hook_cache,
    customtype

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
    setup!(plugin, deps, args...)

Initialize the plugin with the given dependencies and arguments (e.g. shared state).

This lifecycle hook will be called when the application loads a plugin. Plugins.jl does not (yet) helps with this,
application developers should do it manually, right after the PluginStack was created, before the hook_cache() call.
"""
setup!(plugin::Plugin, args...) = nothing

"""
    shutdown!(plugin, sharedstate)

Shut down the plugin.

This lifecycle hook will be called when the application unloads a plugin, e.g. before the application exits.
Plugins.jl does not (yet) helps with this, application developers should do it manually.
"""
shutdown!(plugin::Plugin, args...) = nothing

"""
    customfield(plugin::Plugin, abstract_type::Type, args...)

Provide field specifications to plugin-assembled types.

Using this lifecycle hook the system can define custom plugin-assembled types
(typically structs) based on field specifications provided by plugins.
E.g. an error type can be extended with debug information.

A plugin can provide zero or one field to every assembled type.
To provide a field, return a [`FieldSpec`](@ref).
    
The assembled type will be a subtype of `abstract_type`. To allow differently
configured systems to run in the same Julia session, new types may be assembled
for every instance of the system.

!!! warning "Metaprogramming may make you unhappy"
    Although plugin-assmebled types are designed to help doing metaprogramming in a controlled
    fashion, it is usually better to use non-meta solutions instead. E.g. Store plugin state
    inside the plugin, collect data from multiple plugins using lifecycle hooks, etc.
"""
customfield(plugin::Plugin, abstract_type::Type, args...) = nothing

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

setup_hook! = create_lifecyclehook(setup!)
shutdown_hook! = create_lifecyclehook(shutdown!)
customfield_hook = create_lifecyclehook(customfield)

setup!(stack::PluginStack, sharedstate) = setup_hook!(stack, sharedstate)
shutdown!(stack::PluginStack, sharedstate) = shutdown_hook!(stack, sharedstate)
customfields(stack::PluginStack, abstract_type::Type) = customfield_hook(stack, abstract_type)

include("assembled_types.jl")
include("deps.jl")

end # module
