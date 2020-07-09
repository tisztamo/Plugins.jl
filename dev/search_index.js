var documenterSearchIndex = {"docs":
[{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"EditURL = \"https://github.com/tisztamo/Plugins.jl/blob/master/docs/examples/gettingstarted.jl\"","category":"page"},{"location":"gettingstarted/#Getting-Started-1","page":"Getting Started","title":"Getting Started","text":"","category":"section"},{"location":"gettingstarted/#Installation-1","page":"Getting Started","title":"Installation","text":"","category":"section"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"The package is registered, so simply: julia> using Pkg; Pkg.add(\"Plugins\")","category":"page"},{"location":"gettingstarted/#Your-first-plugin-1","page":"Getting Started","title":"Your first plugin","text":"","category":"section"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"This will be a simple performance counter to measure the frequency of tick() calls. It calculates the rolling average of elapsed time between calls to the tick() hook:","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"using Plugins, Printf\n\nmutable struct PerfPlugin <: Plugin\n    last_call_ts::UInt64\n    avg_elapsed::Float64\n    PerfPlugin() = new(time_ns(), 0)\nend\n\nPlugins.symbol(::PerfPlugin) = :perf\n\ntickfreq(me::PerfPlugin) = 1e9 / me.avg_elapsed","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"When the tick() hook is called, the plugin calculates the time difference to the stored timestamp of the last call, and updates the exponential moving average:","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"const alpha = 0.999\n\nfunction tick(me::PerfPlugin, app)\n    ts = time_ns()\n    diff = ts - me.last_call_ts\n    me.last_call_ts = ts\n    me.avg_elapsed = alpha * me.avg_elapsed + (1.0 - alpha) * diff\nend;\nnothing #hide","category":"page"},{"location":"gettingstarted/#The-application-1","page":"Getting Started","title":"The application","text":"","category":"section"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"Now let's create the base system. Its state holds the plugins and a counter:","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"mutable struct App\n    plugins::PluginStack\n    tick_counter::UInt\n    App(plugins, hookfns) = new(PluginStack(plugins, hookfns), 0)\nend","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"There is a single operation on the app, which increments a counter in a cycle and calls the tick() hook:","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"function tickerop(app::App)\n    tickhook = hooks(app).tick\n    tickerop_kern(app, tickhook) # Using a function barrier to get ~5ns per plugin activation\nend\n\nfunction tickerop_kern(app::App, tickhook)\n    for i = 1:1e6\n        app.tick_counter += 1\n        tickhook()\n    end\nend;\nnothing #hide","category":"page"},{"location":"gettingstarted/#Running-it-1","page":"Getting Started","title":"Running it","text":"","category":"section"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"The last step is to initialize the app, call the operation, and read out the performance measurement from the plugin:","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"const app = App([PerfPlugin()], [tick])\ntickerop(app)\nprintln(\"Average cycle time: $(@sprintf(\"%.2f\", app.plugins[:perf].avg_elapsed)) nanoseconds, Frequency: $(@sprintf(\"%.2f\", tickfreq(app.plugins[:perf]) / 1e6)) MHz\")","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"That was on the CI. On an i7 7700K I typically get around 21.15ns / 47.3 MHz","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"You can find this example under docs/examples/gettingstarted.jl if you check out the repo.","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"","category":"page"},{"location":"gettingstarted/#","page":"Getting Started","title":"Getting Started","text":"This page was generated using Literate.jl.","category":"page"},{"location":"guide/#Guide-1","page":"Guide","title":"Guide","text":"","category":"section"},{"location":"guide/#","page":"Guide","title":"Guide","text":"Here you will find a more in-depth example with","category":"page"},{"location":"guide/#","page":"Guide","title":"Guide","text":"Lifecycle hooks\nStoring the hook cache in a type parameter for maximum performance (zero overhead)","category":"page"},{"location":"guide/#","page":"Guide","title":"Guide","text":"The guide is not yet written. In the meantime you can check the tests, they cover every topic and they are named and organized in the hope that you will find them helpful.","category":"page"},{"location":"reference/#Reference-1","page":"Reference","title":"Reference","text":"","category":"section"},{"location":"reference/#","page":"Reference","title":"Reference","text":"Modules = [Plugins]","category":"page"},{"location":"reference/#Plugins.Plugin","page":"Reference","title":"Plugins.Plugin","text":"abstract type Plugin\n\nProvides default implementations of lifecycle hooks.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.PluginStack","page":"Reference","title":"Plugins.PluginStack","text":"PluginStack\n\nHolds all the plugins loaded into an application.\n\nImplements the iteration interface, and gives access using symbols, e.g. pluginstack[:logger]\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.hook_cache-Tuple{Any,Any}","page":"Reference","title":"Plugins.hook_cache","text":"hook_cache(hookfns, sharedstate)\n\nCreate a cache of HookLists from the list of hook functions.\n\nReturns a NamedTuple with an entry for every handler.\n\nExamples\n\ncache = hook_cache([hook1, hook2], app)\ncache.hook1()\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.hooklist-Union{Tuple{TSharedState}, Tuple{Any,Any,TSharedState}} where TSharedState","page":"Reference","title":"Plugins.hooklist","text":"function hooklist(plugins, hookfn, sharedstate::TSharedState) where {TSharedState}\n\nCreate a HookList which allows fast, inlinable call to the merged implementations of hookfn for TSharedState by the given plugins.\n\nA plugin of type TPlugin found in plugins will be referenced in the resulting HookList if there is a method with the following signature: hookfn(::TPlugin, ::TSharedState, ...)\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.hooks","page":"Reference","title":"Plugins.hooks","text":"function hooks(stack::PluginStack, rebuild = true)\n\n\n\n\n\n","category":"function"},{"location":"reference/#Plugins.setup!-Tuple{Plugin,Any}","page":"Reference","title":"Plugins.setup!","text":"setup!(plugin, sharedstate)\n\nInitialize the plugin with the given shared state.\n\nThis lifecycle hook should be called when the application loads a plugin. Plugins.jl does not (yet) helps with this, application developers should do it manually, right after the PluginStack was created, before the hook_cache() call.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.shutdown!-Tuple{Plugin,Any}","page":"Reference","title":"Plugins.shutdown!","text":"shutdown!(plugin, sharedstate)\n\nShut down the plugin.\n\nThis lifecycle hook should be called when the application unloads a plugin, e.g. before the application exits. Plugins.jl does not (yet) helps with this, application developers should do it manually.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.symbol-Tuple{Plugin}","page":"Reference","title":"Plugins.symbol","text":"symbol(plugin)\n\nReturn the unique Symbol of this plugin if it exports an API to other plugins.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.HookList","page":"Reference","title":"Plugins.HookList","text":"HookList{TNext, THandler, TPlugin, TSharedState}\n\nProvides fast, inlinable call to the implementations of a specific hook.\n\nYou can get a HookList by calling hooklist() directly, or using hooks().\n\nThe HookList can be called with a ::TSharedState and an arbitrary number of extra arguments. If any of the plugins referenced in the list fails to handle the extra arguments, the call will raise a MethodError\n\n\n\n\n\n","category":"type"},{"location":"#Introduction-1","page":"Introduction","title":"Introduction","text":"","category":"section"},{"location":"#","page":"Introduction","title":"Introduction","text":"A plugin is a chunk of code that extends the functionality of a system. It is much like a component, as it has its own lifecycle and it reacts to events generated by the system. A plugin-based architecture can be useful to develop maintainable software, but its dynamic nature introduces a performance penalty that is not always acceptable.","category":"page"},{"location":"#","page":"Introduction","title":"Introduction","text":"Plugins.jl helps by analyzing the plugins loaded into the system and generating types to leverage the \"Just Ahead Of Time\" compilation of Julia, thus allowing full optimization. Execution of plugin code can be just as performant as a manually composed system. Inlinable hook implementations will be merged into a single function body, and non-implementing plugins are skipped with zero overhead.","category":"page"},{"location":"#Plugin-based-architecture-1","page":"Introduction","title":"Plugin-based architecture","text":"","category":"section"},{"location":"#","page":"Introduction","title":"Introduction","text":"A plugin implements so-called hooks: functions that the system will call at specific points of its inner life. You can think of hooks as they were event handlers, when the event source is the \"base system\".","category":"page"},{"location":"#","page":"Introduction","title":"Introduction","text":"The system is configured with an array of plugins. If multiple plugins implement the same hook, they will be called in their order, with any plugin able to halt the processing by simply returning true.","category":"page"},{"location":"#","page":"Introduction","title":"Introduction","text":"Plugins have their own state, but they can access a shared state/configuration, and they can also publish an API by registering a symbol that other plugins can search for.","category":"page"}]
}
