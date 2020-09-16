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

customfield(plugin::Plugin, abstract_type::Type) = nothing

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
    PluginStack(plugins, hookfns = []) = new(plugins, hookfns, symbolcache(plugins), nothing)
end

symbolcache(plugins) = Dict([(symbol(plugin), plugin) for plugin in plugins])

function updated!(stack::PluginStack)
    stack.symbolcache = symbolcache(stack.plugins)
    stack.hookcache = nothing
end

function update!(stack::PluginStack, op, args...)
    retval = op(stack.plugins, args...)
    updated!(stack)
    return retval
end

Base.push!(stack::PluginStack, items...) = update!(stack, Base.push!, items...)
Base.pushfirst!(stack::PluginStack, items...) = update!(stack, Base.pushfirst!, items...)
Base.pop!(stack::PluginStack, items...) = update!(stack, Base.pop!, items...)
Base.popfirst!(stack::PluginStack, items...) = update!(stack, Base.popfirst!, items...)
Base.empty!(stack::PluginStack, items...) = update!(stack, Base.empty!, items...)

Base.isempty(stack::PluginStack) = Base.isempty(stack.plugins)
Base.length(stack::PluginStack) = length(stack.plugins)
Base.iterate(stack::PluginStack) = iterate(stack.plugins)
Base.iterate(stack::PluginStack, state) = iterate(stack.plugins, state)

Base.get(stack::PluginStack, key::Symbol, default=nothing) = get(stack.symbolcache, key, default)
Base.getindex(stack::PluginStack, idx) = getindex(stack.plugins, idx)
Base.getindex(stack::PluginStack, key::Symbol) = get(stack, key)
Base.setindex!(stack::PluginStack, params...) = update!(stack, setindex!, params...)

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
`hook_cache()`, and stored in `pluginstack` for quick access later.

The hook cache will be rebuilt if the `rebuild` argument is true, or if pluginstack was modified.
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
                push!(results, (e, catch_backtrace()))
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
customfield(stack::PluginStack, abstract_type::Type) = customfield_hook(stack, abstract_type)

abstract type TemplateStyle end
struct ImmutableStruct <: TemplateStyle end
struct MutableStruct <: TemplateStyle end

TemplateStyle(::Type) = MutableStruct()

struct FieldSpec
    name::Symbol
    type::Type
    constructor::Union{Function, DataType}
end
FieldSpec(name, type::Type, constructor::Union{Function, DataType} = type) = FieldSpec(Symbol(name), type, constructor)

structfield(spec::FieldSpec) = :($(spec.name)::$(Meta.parse(string(spec.type))))

struct TypeSpec
    name::Symbol
    mod::Module
    parent_type::Type
    fields::Vector{FieldSpec}
end

function structfields(spec::TypeSpec)
    return Expr(:block, map(structfield, spec.fields)...)
end

function default_constructor(spec)
    fieldcalls = map(field -> :($(field.constructor)(params...)), spec.fields)
    retval = :($(spec.name)(params...) = $(Expr(:call, spec.name, fieldcalls...)))
    return retval
end

function typedef end

typedef(::MutableStruct, spec::TypeSpec) = quote
    mutable struct $(spec.name) <: $(spec.parent_type)
        $(structfields(spec))
    end;
    $(default_constructor(spec))
    $(spec.name)
end

typedef(::ImmutableStruct, spec::TypeSpec) = quote
    struct $(spec.name) <: $(spec.parent_type)
        $(structfields(spec))
    end;
    $(default_constructor(spec))
    $(spec.name)
end

function customtype(stack::PluginStack, typename::Symbol, parent_type::Type = Any, target_module::Module = Main)
    hookres = customfield(stack, parent_type)
    if !hookres.allok
        throw(ErrorException("Cannot define custom type, a plugin throwed an error: $hookres"))
    end
    fields = hookres.results
    spec = TypeSpec(typename, target_module, parent_type, fields)
    def = typedef(TemplateStyle(parent_type), spec)
    return Base.eval(target_module, def)
end

end # module
