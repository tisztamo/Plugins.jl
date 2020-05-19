module Plugins

import Base.length, Base.iterate

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
    if hook.handler(hook.plugin, hook.framework) !== false
        hook.next()
    end
    return nothing
end

@inline function (hook::HookList)(event)
    if hook.handler(hook.plugin, hook.framework, event) !== false
        hook.next(event)
    end
    return nothing
end

(hook::HookList{Nothing, T, Nothing, Nothing})() where T = nothing
(hook::HookList{Nothing, T, Nothing, Nothing})(a) where T = nothing

length(l::HookList{Nothing, T, Nothing, Nothing}) where T = 0
length(l::HookList) = 1 + length(l.next)

iterate(l::HookList) = (l, l.next)
iterate(l::HookList, state) = isnothing(state) ? nothing : (state, state.next)
iterate(l::HookList{Nothing, T, Nothing, Nothing}) where T = nothing
iterate(l::HookList, state::HookList{Nothing, T, Nothing, Nothing}) where T = nothing

function hooks(plugin::TPlugin, handler::THandler, framework::TFramework,) where {TFramework, THandler, TPlugin}
    if length(methods(handler, (TPlugin, TFramework))) > 0 || length(methods(handler, (TPlugin, TFramework, Any))) > 0
        return HookList(hooks(next(plugin), handler, framework), handler, plugin, framework)
    end
    return hooks(next(plugin), handler, framework)
end
hooks(plugin::Nothing, handler, framework) = HookList(nothing, (p, f) -> nothing, nothing, nothing)

hooks(framework::TFramework, handler::THandler) where {THandler, TFramework} = hooks(framework.plugins, handler, framework)

end # module
