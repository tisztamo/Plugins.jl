# Plugins

[![Build Status](https://travis-ci.com/tisztamo/Plugins.jl.svg?branch=master)](https://travis-ci.com/tisztamo/Plugins.jl)
[![Codecov](https://codecov.io/gh/tisztamo/Plugins.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tisztamo/Plugins.jl)

A Plugin is a chunk of code that adds functionality to a system. It implements so-called hooks: functions that the system will call at specific points of its inner life (aka Event handlers). 

If multiple plugins implement the same hook, they will be called in the order the plugins were added to the system. Plugins.jl allows full compiler optimization, meaning plugin execution can be just as performant as a manually composed system.

```julia
using Plugins, Test

struct Framework
    plugins
    Framework(plugins) = new(PluginStack(plugins))
end

mutable struct CounterPlugin <: Plugin
    hook1count::Int
    CounterPlugin() = new(0)
end

@inline hook1_handler(plugin::CounterPlugin, framework) = begin
    plugin.hook1count += 1
    return true # Allow other hooks to run. return false to "stop propagation"
end

struct LoggerPlugin <: Plugin end

@inline hook1_handler(plugin::LoggerPlugin, framework) = begin
  println("hook1 called!")
  return true
end

counter = CounterPlugin()
app = Framework([counter, LoggerPlugin()])
hook1 = hooks(app, hook1_handler)

hook1() # Prints "hook1 called" and returns true
@test counter.hook1count === 1
```

At non-critical points you can call `hooks()` every time, but if you cannot waste a few microseconds, you have to cache the result. Note that `hooks()` is _not_ type-stable as it builds a type chain by filtering plugins that impement the specified hook. This means you have to parametrize your framework struct with the performance-critical hooks and call `hooks()` in the constructor. I plan to add a layer that makes this automatically, allowing you to only parametrize with a `PluginStack`.

That's all the documentation at the time, please check the [tests](https://github.com/tisztamo/Plugins.jl/blob/master/test/runtests.jl) for more examples.
