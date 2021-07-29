# Features and usage

## Good work starts with an outline

When using Plugins.jl, you split your system into two separated code domains: The *__base__* outlines the work to be done, and *__plugins__* fill out this outline with implementations. This pattern is widely used among large Julia packages[^pkgsplit], because it helps coordinating developer work in a distributed fashion.

Plugins.jl extends this pattern with a coordination mechanism that allows multiple plugins to work together on the same task. This helps composing the system out of smaller, optional chunks, and also makes it easy to implement dynamic features like value-based message routing (aka dispatch on value) efficiently.

The coordination mechanism is very similar to how DOM event handlers work.

## Hooks

A plugin implements so-called hooks: functions that the system will call at specific points of its inner life. You can think of hooks as they were event handlers, where the event source is the "base system". There are two types of hooks currently:

- *__"Lifecycle hooks"__* are dynamically dispatched, and their results collected. Errors are also collected and do not interfere with other plugins.

- *__"Normal hooks"__* are designed for maximal runtime performance: When multiple plugins implement the same hook, their implementations will be merged together with simple glue code that allows any plugin to stop processing by simply returning true, similar to how DOM event handlers can stop event propagation. An error in a plugin also stops propagation.

This categorization will very likely be changed in a breaking way to allow better tuning of compilation overhead.

## State

Plugins can have their own state, and they can also access a shared state provided by the base system.

## Configuration injection

A "global" (per base system) configuration is passed to plugins during initialization, in the form of keyword
arguments to the constructor. This means that plugins can specialize on the configuration, if performance requirements
dictate that.

## Dependency injection

Plugins can declare other plugins as their *__mandantory dependencies__*.
The system will analyse the dependency graph and initialize plugins accordingly.
Just like configuration, dependencies are injected to the constructor.

Dependency declarations come in the form of types, e.g.:

```julia
Plugins.deps(::Type{Plugin3}) = [Plugin1, Plugin2]
```

Concrete types are concrete dependencies, while abstract types are used as *__"interfaces"__*,
meaning that any concrete subtype of the required abstract type can fulfill the dependency.
The system will dynamically select implementations based on user configuration and specificity
rules, allowing for example test mocking.

## Ad-hoc Inter-plugin communication

Plugins can (informally) publish a runtime API for other plugins to use. To use the API, it is enough to know the
*__symbol__* of the used plugin instead of its (super)type, which allows lightweight duck-typed interoperability:
The "user" plugin asks the system for the plugin with a specific symbol, and calls its API.
Symbols are defined by the type of the plugin, and should be unique among the instantiated plugins in a system.

## Assembled types: Maintainable runtime metaprogramming

Additionally and optionally, the base system can define so-called assembled types. These are composite types that plugins will jointly assemble with every plugin allowed to delegate a single field.

This can help you with performance optimizations that normally would need `@generated` functions or other metaprograming. For example in the [CircoCore.jl](https://github.com/Circo-dev/CircoCore.jl/blob/0cedbb05b94a9e5ae8954d512afcf764bc8e400b/src/space.jl#L95) actor system (the reference application of Plugins.jl), plugins can extend the message type with data used to optimize routing. This is implemented with zero runtime cost, and without any metaprogramming in the plugin itself.

The plugin just declares the field it wants to add to an abstract type,
and the base system will be instantiated with a concrete subtype which was generated to contain the field.
The plugin then can access the field in hooks at its will, while other plugins will not know about it.

[^pkgsplit]: For example: Rackauckas, Chris & Nie, Qing. (2017). [DifferentialEquations.jl – A Performant and Feature-Rich Ecosystem for Solving Differential Equations in Julia.](https://www.researchgate.net/publication/317162482_DifferentialEquationsjl_-_A_Performant_and_Feature-Rich_Ecosystem_for_Solving_Differential_Equations_in_Julia) Journal of Open Research Software. 5. 10.5334/jors.151.