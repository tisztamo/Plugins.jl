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
    name        :: Symbol
    type        :: Type
    constructor :: Union{Function, DataType}
end
"""
    FieldSpec(name, type::Type, constructor::Union{Function, DataType} = type)

Field specification for plugin-assembled types.

Note that every field of an assembled type will be constructed with the same arguments.
 Possibly The constructor will be called when the system 
"""
FieldSpec(name, type::Type, constructor::Union{Function, DataType} = type) = FieldSpec(Symbol(name), type, constructor)

@inline structfield(spec::FieldSpec) = :($(spec.name)::$(Meta.parse(string(spec.type))))

struct TypeSpec
    name::Symbol
    parent_type::Type
    fields::Vector{FieldSpec}
    params::Vector{Symbol}
    mod::Module
end

function structfields(spec::TypeSpec)
    return Expr(:block, map(structfield, spec.fields)...)
end

fieldcalls(spec) = map(field -> :($(field.constructor)(args...; kwargs...)), spec.fields)

function default_constructor(spec)
    retval = :(TYPE_NAME(args...; kwargs...) = $(Expr(:call, :TYPE_NAME, fieldcalls(spec)...)))
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
    mutable struct TYPE_NAME{$(spec.params...)} <: $(spec.parent_type)
        $(structfields(spec))
    end;
    $(default_constructor(spec))
    TYPE_NAME
end

typedef(::ImmutableStruct, spec::TypeSpec) = begin
    mutabledef = typedef(MutableStruct(), spec)
    mutabledef.args[2].args[1] = false
    return mutabledef
end

"""
    customtype(stack::PluginStack, typename::Symbol, abstract_type::Type, target_module::Module = Main; unique_name = true)

Assemble a type with fields provided by the plugins in `stack`.

`abstract_type` will be the supertype of the assembled type.

If `unique_name` == `true`, then `typename` will be suffixed with a structure-dependent id.
The  id is generated as a hash of the evaluated expression (with the :TYPE_NAME placeholder
used instead of the name), meaning that for the same id will be generated for a given type
when the same plugins with the same source code are loaded.

# Examples

Assembling a type `AppStateImpl <: AppState` and parametrizing the app with
it. 
```julia
abstract type AppState end

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
    Assembled types can make your code less readable, use them sparingly!
"""
function customtype(
    stack         :: PluginStack,
    typename      :: Symbol,
    abstract_type :: Type = Any,
    params        :: Vector{Symbol} = Symbol[],
    target_module :: Module = Main;
    unique_name   =  true
    )
    hookres = customfields(stack, abstract_type)
    if !hookres.allok
        throw(ErrorException("Cannot define custom type, a plugin throwed an error: $hookres"))
    end
    fields = filter(f -> !isnothing(f), hookres.results)
    spec = TypeSpec(typename, abstract_type, fields, params, target_module)
    def = inject_name(typedef(TemplateStyle(abstract_type), spec), spec, unique_name)
    try
        retval = Base.eval(target_module, def)
    catch e
        @info "Exception while assembling custom type: $def"
        rethrow(e)
    end
end

function inject_name(typedef::Expr, spec::TypeSpec, unique_name)
    suffix = unique_name ? hashstring(typedef) : ""
    name = Symbol(string(spec.name) * "_" * suffix)
    recursive_replace!(typedef, :TYPE_NAME => name)
end

hashstring(typedef::Expr) = string(hash(typedef) % 1679616; base=36) # 4 alphanumeric chars

function recursive_replace!(expr::Expr, source_target_pair)
    replace!(expr.args, source_target_pair)
    foreach(ex -> recursive_replace!(ex, source_target_pair), expr.args)
    return expr
end
recursive_replace!(s, _) = s
