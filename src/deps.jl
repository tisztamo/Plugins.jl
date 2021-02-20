using InteractiveUtils

struct RegisteredPlugin
    type::Type
    deps::Vector{<:Type}
end

const registry = IdDict{Type,RegisteredPlugin}()

function register(plugin::Type, dependencies = deps(plugin))
    registry[plugin] = RegisteredPlugin(plugin, dependencies)
    return nothing
end

"""
    Plugins.deps(::Type{T}) = Type[] # where T is your plugin type

Add a method to declare your dependencies.

The plugin type must have a constructor accepting an instance of every of their dependencies.

# Examples

abstract type InterfaceLeft end
struct ImplLeft <: InterfaceLeft end

abstract type InterfaceRight end
struct ImplRight <: InterfaceRight end

Plugins.deps(::Type{ImplLeft}) = [ImplRight]
"""
deps(t) = Type[]


"""
    function autoregister(base=Plugin)

Find and register every concrete subtype of 'base' as a Plugin
"""
function autoregister(base=Plugin)
    for t in subtypes(base) # TODO subtypes is extremely slow
        if isconcretetype(t)
            if !haskey(registry, t)
                @debug "Auto-registering plugin type $t"
                register(t)
            end
        else
            autoregister(t)
        end
    end
end

# t1 implements t2 or
# t1 is an interface that is more specific than t2, or
# t1 and t2 are implementations and t1's direct interface
# is a real subinterface of t2's
function ismorespecific(t1, t2)
    t1 <: t2 && return true
    if isconcretetype(t2) && isconcretetype(t2) &&
        supertype(t1) != supertype(t2) &&
        supertype(t2) != Plugin &&
        supertype(t1) <: supertype(t2)
        return true
    end
    return false
end

function getplugin(t::Type, throw_on_missing=true)::RegisteredPlugin
    found = get(registry, t, nothing)
    !isnothing(found) && return deepcopy(registry[t])
    for p in values(registry) # find the most specific implementation
        if ismorespecific(p.type, t) && (isnothing(found) || ismorespecific(p.type, found.type))
            found = p
        end
    end
    isnothing(found) && throw_on_missing && error("No implementing plugin found for $t")
    return deepcopy(found)
end
getplugin(p::RegisteredPlugin) = p
getplugin(p) = error("The $(typeof(p)) is instantiated. Please provide a type instead!")

allplugins() = values(registry)
plugintypes(plugins) = map(p->p.type, plugins)
plugindeps(plugins) = unique(Iterators.flatten(map(p->p.deps, plugins)))
findimplementation(req, impls) = findfirst(t -> t <: req, impls)

function missingdeps(plugins, dependencies)
    deptypes = plugintypes(dependencies)
    return filter(plugindeps(plugins)) do p
        isnothing(findimplementation(p, deptypes))
    end
end

function find_deps(plugins)
    m = missingdeps(plugins, allplugins())
    length(m) != 0 && error("Missing dependencies: $m")
    lastlength = 0
    retval = plugins
    while lastlength != length(retval)
        lastlength = length(retval)
        retval = vcat(retval, getplugin.(missingdeps(retval, retval)))
    end
    return retval
end

_selectone(plugins) = plugins[findlast(p -> isempty(p.deps), plugins)]

function _removedep(plugins, dep)
    foreach(p -> filter!(d -> !(dep.type <: d), p.deps), plugins)
    return filter!(p -> !(dep.type <: p.type), plugins)
end

function instantiation_order(plugintypes)
    plugins = getplugin.(plugintypes)
    deps = getplugin.(find_deps(plugins))
    remaining = unique(vcat(deps, plugins))
    sorted = RegisteredPlugin[]
    while !isempty(remaining)
        p = _selectone(remaining)
        push!(sorted, registry[p.type])
        _removedep(remaining, p)
    end
    return map(p -> p.type, sorted)
end

# Return a reordered copy of instances to reflect the order of reqplugintypes.
# instances not represented in plugintypes will go to the end of the
# returned vector in their original order
function order_instances(instances, plugintypes)
    cache = Dict([typeof(instance) => instance for instance in instances])
    result = []
    for t in plugintypes
        instance = pop!(cache, getplugin(t, false).type)
        push!(result, instance)
    end
    for instance in values(cache)
        push!(result, instance)
    end
    return result
end

function instantiate(plugintypes; options...)
    order = instantiation_order(plugintypes)
    instances = []
    cache = IdDict{Type, Any}()
    for t in order
        p = getplugin(t)
        injected_deps = (get(cache, getplugin(dep).type, nothing) for dep in p.deps)
        instance = t(injected_deps...; options...)
        cache[p.type] = instance
        push!(instances, instance)
    end
    return order_instances(instances, plugintypes)
end

