"""
    symbol(plugin)

Return the per-PluginStack unique Symbol of this plugin if it exports an API to other plugins.
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
    shutdown!(plugin, args...)

Shut down the plugin.

This lifecycle hook will be called when the application unloads a plugin,
e.g. before the application exits.
Plugins.jl does not (yet) helps with this, application developers should do it manually.
"""
shutdown!(plugin::Plugin, args...) = nothing

"""
    customfield(plugin::Plugin, abstract_type::Type, args...) = nothing

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
    request_stage(plugin::Plugin, args...)::Stage

Request a new stage iteration by returning a Stage representing it.

This lifecycle hook will be called repeatedly to ask plugins
their wish to stage. If a plugin returns a `Stage` instance
and the request is accepted, the stage will start immediately.

If more than one plugins ask for staging, their request will
be merged if possible and only one stage will run. If the stages
are incompatible, meaning that different sets of plugins handle the
`prepeare` hook of the stages, then only a compatible subset
of them will run.

Plugins should continue requesting staging until their wish gets
fulfilled.
"""
request_stage(plugin::Plugin, args...) = nothing

"""
    prepare_stage(plugin::Plugin, stage::Stage)

Lifecycle hook to prepare the plugin for the next stage.
If the stage is an `EvalStage` and the plugin needs to evaluate
code, this is the point to do it.
"""
prepare_stage(plugin::Plugin, stage, args...) = nothing

"""
    enter_stage(plugin::Plugin, stage::Stage, args...)

Lifecycle hook marking the start of the next stage.

Types are reasssembled at this point. If `stage isa EvalStage`,
then the world is already updated. (execution reached toplevel)

"""
enter_stage(plugin::Plugin, stage, args...) = nothing

"""
    leave_stage(plugin::Plugin, stage::Stage, nextstage::Stage, args...)

Lifecycle hook marking the end of a stage.
"""
leave_stage(plugin::Plugin, stage, args...) = nothing

setup_hook! = create_lifecyclehook(setup!)
shutdown_hook! = create_lifecyclehook(shutdown!)
customfield_hook = create_lifecyclehook(customfield)
request_stage_hook = create_lifecyclehook(request_stage)
prepare_stage_hook = create_lifecyclehook(prepare_stage)
enter_stage_hook = create_lifecyclehook(enter_stage)
leave_stage_hook = create_lifecyclehook(leave_stage)

setup!(stack::PluginStack, sharedstate) = setup_hook!(stack, sharedstate)
shutdown!(stack::PluginStack, sharedstate) = shutdown_hook!(stack, sharedstate)
customfields(stack::PluginStack, abstract_type::Type) = customfield_hook(stack, abstract_type)
