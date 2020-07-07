# Plugins

[![Build Status](https://travis-ci.com/tisztamo/Plugins.jl.svg?branch=master)](https://travis-ci.com/tisztamo/Plugins.jl)
[![Codecov](https://codecov.io/gh/tisztamo/Plugins.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tisztamo/Plugins.jl)

A Plugin is a chunk of code that adds functionality to a system. It implements so-called hooks: functions that the system will call at specific points of its inner life (aka Event handlers). 

The system is configured with an array of plugins. If multiple plugins implement the same hook, they will be called in their order, with any plugin able to halt the processing. Plugins can also publish an API by registering a symbol.

Plugins.jl allows full compiler optimization, meaning plugin execution can be just as performant as a manually composed system. Inlinable hook implementations will be merged into a single function body, and non-implementing plugins are skipped with zero overhead.

```julia
# Simple Plugins.jl example with two plugins implementing a hook: A logger and a counter. The logger also
# registers itself to provide an API

using Plugins, Test

struct Framework
    plugins
    Framework(plugins) = new(PluginStack(plugins))
end

struct LoggerPlugin <: Plugin end

function log(me::LoggerPlugin, message)
    println("Logger Plugin in action: $message")
end

function hook1_handler(me::LoggerPlugin, framework)
  log(me, "hook1 called!")
  return false # Allow other hooks to run. return true to "stop propagation"
end

Plugins.symbol(::LoggerPlugin) = :logger

mutable struct CounterPlugin <: Plugin
    hook1count::Int
    CounterPlugin() = new(0)
end

@inline hook1_handler(plugin::CounterPlugin, framework) = begin
    plugin.hook1count += 1
    return false 
end

counter = CounterPlugin()
app = Framework([counter, LoggerPlugin()])
hook1 = hooks(app, hook1_handler)

hook1() # Prints "Logger Plugin in action: hook1 called!" and returns true

@test counter.hook1count === 1

log(app.plugins[:logger], "A log message")
```

At non-critical points you can call `hooks()` every time, but if you cannot waste a few microseconds, you have to cache the result. Note that `hooks()` is _not_ type-stable, because to allow optimization it builds a type chain by filtering plugins that implement the specified hook. 

That's all the documentation at the time, please check the [tests](https://github.com/tisztamo/Plugins.jl/blob/master/test/runtests.jl) for more examples.
