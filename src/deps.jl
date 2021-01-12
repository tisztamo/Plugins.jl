struct RegisteredPlugin
    type::Type
    deps::Vector{Type}
end

const registry = IdDict{Type,RegisteredPlugin}()

function register(plugin::Type, deps::Vector{<:Type} = Type[])
    registry[plugin] = RegisteredPlugin(plugin, deps)
    return nothing
end

function getplugin(t::Type)::RegisteredPlugin
    found = get(registry, t, nothing)
    !isnothing(found) && return deepcopy(registry[t])
    for p in values(registry) # find the most specific implementation
        if p.type <: t && (isnothing(found) || p.type <: found.type )
            found = p
        end
    end
    isnothing(found) && error("No implementing plugin found for $t")
    return deepcopy(found)
end

getplugin(p::RegisteredPlugin) = p
allplugins() = values(registry)
plugintypes(plugins) = map(p->p.type, plugins)
deps(plugins) = unique(Iterators.flatten(map(p->p.deps, plugins)))::Vector{Type}
findimplementation(req, impls) = findfirst(t -> t <: req, impls)

function missingdeps(plugins, dependencies)
    _types = plugintypes(dependencies)
    return filter(p -> isnothing(findimplementation(p, _types)), deps(plugins))
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

function instantiate(plugintypes; options...)
    order = instantiation_order(plugintypes)
    instances = []
    cache = IdDict{Type, Any}()
    for t in order
        p = getplugin(t)
        injected = (get(cache, getplugin(dep).type, nothing) for dep in p.deps)
        instance = t(injected...; options...)
        cache[p.type] = instance
        push!(instances, instance)
    end
    return instances
end

