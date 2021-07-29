# Introduction

## Modules on steroids

Plugins.jl:

- Shapes your code by helping to implement the popular *__"extensions"__* architectural pattern.
- Provides *__dependency management/injection__* for more declarative code structuring and easier testing.
- *__Zero Cost Abstraction__*: Plugin code is inlinable. You've read it right: *_inlinable_*.
- Allows *__maintainable runtime metaprogramming__* in a controlled way that prevents meta code from taking over your codebase.
- Defines a standard *__plugin lifecycle__* (sort of).

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

