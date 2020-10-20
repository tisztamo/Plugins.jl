# Introduction

## Plugins.jl highlights

- Helps implementing the popular "extensions" architectural pattern.
- Zero Cost Abstraction: Plugin code is inlinable. You've read it right: *inlinable*.
- Allows maintainable metaprogramming in a controlled way that prevents meta code from taking over your codebase.

## What plugins are in general?

Feel free to skip this section if you know the answer.

A plugin is a chunk of code that extends the functionality of a system. It is not usable in itself, it has to be "plugged" into a system where it reacts to events and works together with other plugins. Plugins are sometimes called "extensions", and they can be found everywhere: from IDEs to browsers, from music software to operating systems.

A software built with plugins is like a kitchen where different devices work together to help you. When you want to drink some tea, you will need a cup so that you can boil water in the microwave. If you drink a lot of tea, you may buy and plug in a kettle, beacuse that is better for boiling water. A good cup can work together with both the micro and the kettle, and you don't have to throw out your micro, you can still warm up your food with it.

Now, abstractions in programming can do something like this: to help replacing implementations by separating interface from implementation.

Plugins provide the highest level abstraction layer of a system. This level is ideally so flexible that the user can easily replace parts of the system without programming, maybe even at runtime. You install a plugin and it just works.

## The performance problem

The plugin-based architecture is a popular way to develop maintainable and extensible software, but its dynamic nature introduces a performance penalty that is not always acceptable. You tipically cannot hook into performance-critical points.

Plugins.jl helps by analyzing the plugins loaded into the system and generating efficient, statically dispatched event handling code, thus allowing full optimization.

With Plugins.jl, execution of plugin code can be just as performant as a manually composed system. *Inlinable hook implementations will be merged into a single function body, and non-implementing plugins are skipped with zero overhead.*

## Plugin-based architecture with Plugins.jl

#### Good work starts with an outline
When using Plugins.jl, you split your system into two separated code domains: The *base* outlines the work to be done, and *plugins* fill out this outline with implementations. This pattern is widely used among large Julia packages[^pkgsplit], because it helps coordinating developer work in a distributed fashion.

Plugins.jl extends this pattern with a coordination mechanism that allows multiple plugins to work together on the same task. This helps composing the system out of smaller, optional chunks, and also makes it easy to implement dynamic features like value-based message routing (aka dispatch on value) efficiently.

The coordination mechanism is very similar to how DOM event handlers work.

#### Hooks

A plugin implements so-called hooks: functions that the system will call at specific points of its inner life. You can think of hooks as they were event handlers, where the event source is the "base system".

The system is configured with an array of plugins. If multiple plugins implement the same hook, they will be called in their order, with any plugin able to halt the processing by simply returning `true`.

Plugins can have their own state, but they can also access a shared state/configuration, and they can publish an API for other plugins to use.

#### Maintainable metaprogramming

Additionally and optionally, the base system can define so-called assembled types. These are composite types that plugins will jointly assemble with every plugin allowed to delegate a single field.

This can help you with performance optimizations that normally would need `@generated` functions or other metaprograming. For example in the [CircoCore.jl](https://github.com/Circo-dev/CircoCore.jl/blob/0cedbb05b94a9e5ae8954d512afcf764bc8e400b/src/space.jl#L95) actor system (the reference application of Plugins.jl), plugins can extend the message type with data used to optimize routing. This is implemented with zero runtime cost, and without any metaprogramming in the plugin itself.

[^pkgsplit]: For example: Rackauckas, Chris & Nie, Qing. (2017). [DifferentialEquations.jl – A Performant and Feature-Rich Ecosystem for Solving Differential Equations in Julia.](https://www.researchgate.net/publication/317162482_DifferentialEquationsjl_-_A_Performant_and_Feature-Rich_Ecosystem_for_Solving_Differential_Equations_in_Julia) Journal of Open Research Software. 5. 10.5334/jors.151.