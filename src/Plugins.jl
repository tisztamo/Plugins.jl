module Plugins

export Plugin, TerminalPlugin, hooks

abstract type Plugin end
next(plugin) = plugin.next

struct TerminalPlugin <: Plugin
    next::Nothing
    TerminalPlugin() = new(nothing)
end

struct HookList{TNext, THandler, TPlugin, TFramework}
    next::TNext
    handler::THandler
    plugin::TPlugin
    framework::TFramework
end

@inline function (hook::HookList)()
    hook.handler(hook.plugin, hook.framework)
    hook.next()
end

(hook::HookList{Nothing, T, Nothing})() where T = nothing

function hooks(plugin::TPlugin, handler::THandler, framework::TFramework,) where {TFramework, THandler, TPlugin}
    if length(methods(handler, (TPlugin, TFramework))) > 0
        return HookList(hooks(next(plugin), handler, framework), handler, plugin, framework)
    end
    return hooks(next(plugin), handler, framework)
end
hooks(plugin::Nothing, handler, framework) = HookList(nothing, (p, f) -> nothing, nothing, nothing)

hooks(framework::TFramework, handler::THandler) where {THandler, TFramework} = hooks(framework.firstplugin, handler, framework)


function nexthook(plugin::TPlugin, handler::THandler) where {THandler, TPlugin}

end

end # module
