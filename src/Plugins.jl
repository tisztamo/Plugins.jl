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

"""
    customfield(plugin::Plugin, abstract_type::Type)

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

"""
    struct ImmutableStruct <: TemplateStyle end

Plugin-assembled types marked as `ImmutableStruct` will be generated as a `struct`.
"""
struct ImmutableStruct <: TemplateStyle end

"""
    struct MutableStruct <: TemplateStyle end

Plugin-assembled types marked as `MutableStruct` will be generated as a `mutable struct`.
"""
struct MutableStruct <: TemplateStyle end

"""
    TemplateStyle(::Type) = MutableStruct()

Trait to select the template used for plugin-assembled types

Use [`MutableStruct`](@ref) (default), [`ImmutableStruct`](@ref), or subtype
it when you want to create your own template.

#Examples

Assembling immutable structs:

```julia
abstract type DebugInfo end
Plugins.TemplateStyle(::Type{DebugInfo}) = Plugins.ImmutableStruct()
```

Defining your own template (see also  [`typedef`](@ref) ):

```julia
struct CustomTemplate <: Plugins.TemplateStyle end
Plugins.TemplateStyle(::Type{State}) = CustomTemplate()
```
"""
TemplateStyle(::Type) = MutableStruct()

struct FieldSpec
    name::Symbol
    type::Type
    constructor::Union{Function, DataType}
end
"""
    FieldSpec(name, type::Type, constructor::Union{Function, DataType} = type)

Field specification for plugin-assembled types.

Note that every field of an assembled type will be constructed with the same arguments.
 Possibly The constructor will be called when the system 
"""
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

"""
    typedef(templatestyle, spec::TypeSpec)::Expr

Return an expression defining a type.

Implement it for your own template styles. More info in the
[tests](https://github.com/tisztamo/Plugins.jl/blob/master/test/customfields.jl).
"""
function typedef end

typedef(::MutableStruct, spec::TypeSpec) = quote
    mutable struct $(spec.name) <: $(spec.parent_type)
        $(structfields(spec))
    end;
    $(default_constructor(spec))
    $(spec.name)
end

typedef(::ImmutableStruct, spec::TypeSpec) = begin
    mutabledef = typedef(MutableStruct(), spec)
    mutabledef.args[2].args[1] = false
    return mutabledef
end

"""
    customtype(stack::PluginStack, typename::Symbol, abstract_type::Type, target_module::Module = Main)

Assemble a type with fields provided the plugins in `stack`.

`abstract_type` will be the supertype of the assembled type.

# Examples

Assembling a type `AppStateImpl <: AppState` and parametrizing the app with
it. 
```julia
mutable struct CustomFieldsApp{TCustomState}
    state::TCustomState
    function CustomFieldsApp(plugins, hookfns, stateargs...)
        stack = PluginStack(plugins, hookfns)
        state_type = customtype(stack, :AppStateImpl, AppState)
        return new{state_type}(Base.invokelatest(state_type, stateargs...))
    end
end
```
!!! note "The need for `invokelatest`"
    We need to use `invokelatest` to instantiate a newly generated type. To use 
    the generated type normally, first you have to allow control flow to go to the top-level
    scope after the type was generated. See also the [docs](https://docs.julialang.org/en/v1/manual/methods/#Redefining-Methods)
!!! warning "Antipattern"
    Assembling state types is an antipattern, because plugins can have their own state.
    (This may provide better performance in a few cases though)
"""
function customtype(stack::PluginStack, typename::Symbol, abstract_type::Type, target_module::Module = Main)
    hookres = customfield(stack, abstract_type)
    if !hookres.allok
        throw(ErrorException("Cannot define custom type, a plugin throwed an error: $hookres"))
    end
    fields = hookres.results
    spec = TypeSpec(typename, target_module, abstract_type, fields)
    def = typedef(TemplateStyle(abstract_type), spec)
    return Base.eval(target_module, def)
end

end # module
