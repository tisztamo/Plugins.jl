var documenterSearchIndex = {"docs":
[{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"EditURL = \"https://github.com/tisztamo/Plugins.jl/blob/main/docs/examples/gettingstarted.jl\"","category":"page"},{"location":"gettingstarted/#Getting-Started","page":"Getting Started","title":"Getting Started","text":"","category":"section"},{"location":"gettingstarted/#Motivation","page":"Getting Started","title":"Motivation","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"Let's say you are writing a lib which performs some work in a loop quickly (up to several million times per second). You need to allow your users to monitor this loop, but the requirements vary: One user just wants to count the total number of cycles, another wants to measure the performance and write some metrics to a file regularly, etc. The only requirement that everybody has is maximum performance.","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"Maybe you also have an item on your wishlist: To allow your less techie users to configure the monitoring without coding. Sometimes you even dream of reconfiguring the monitoring while the app is running...","category":"page"},{"location":"gettingstarted/#Installation","page":"Getting Started","title":"Installation","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"The package is registered, so simply: julia> using Pkg; Pkg.add(\"Plugins\"). (repo)","category":"page"},{"location":"gettingstarted/#Your-first-and-second-plugins","page":"Getting Started","title":"Your first and second plugins","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"The first one simply counts the calls to the tick() hook.","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"using Plugins, Printf, Test\n\nmutable struct CounterPlugin <: Plugin\n    count::UInt\n    CounterPlugin() = new(0)\nend\n\nPlugins.symbol(::CounterPlugin) = :counter # For access from the outside / from other plugins\nPlugins.register(CounterPlugin)\n\nfunction tick(me::CounterPlugin, app)\n    me.count += 1\nend;\nnothing #hide","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"The second will measure the frequency of tick() calls:","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"mutable struct PerfPlugin <: Plugin\n    last_call_ts::UInt64\n    avg_elapsed::Float32\n    PerfPlugin() = new(time_ns(), 0)\nend\n\nPlugins.symbol(::PerfPlugin) = :perf\nPlugins.register(PerfPlugin)\n\n\ntickfreq(me::PerfPlugin) = 1e9 / me.avg_elapsed;\nnothing #hide","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"When the tick() hook is called, it calculates the time difference to the stored timestamp of the last call, and updates the exponential moving average:","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"const alpha = 1.0f-3\n\nfunction tick(me::PerfPlugin, app)\n    ts = time_ns()\n    diff = ts - me.last_call_ts\n    me.last_call_ts = ts\n    me.avg_elapsed = alpha * Float32(diff) + (1.0f0 - alpha) * me.avg_elapsed\nend;\nnothing #hide","category":"page"},{"location":"gettingstarted/#The-application","page":"Getting Started","title":"The application","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"Now let's create the base system. Its state holds the plugins and a counter (just to cross-check the CounterPlugin):","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"mutable struct App\n    plugins::PluginStack\n    tick_counter::UInt\n    App(plugins, hookfns) = new(PluginStack(plugins, hookfns), 0)\nend","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"There is a single operation on the app, which increments the tick_counter in a cycle and calls the tick() hook:","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"function tickerop(app::App)\n    tickhook = hooks(app).tick\n    tickerop_kern(app, tickhook) # Using a function barrier to get ~5ns per hook activation\nend\n\nfunction tickerop_kern(app::App, tickhook)\n    for i = 1:1e6\n        app.tick_counter += 1\n        tickhook(app) # We can pass shared state to plugins on the hook. Here, for simplicity, the whole app.\n    end\nend;\nnothing #hide","category":"page"},{"location":"gettingstarted/#Running-it","page":"Getting Started","title":"Running it","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"The last step is to initialize the app, call the operation, and read out the performance measurement from the plugins:","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"app = App([CounterPlugin, PerfPlugin], [tick])\ntickerop(app)\n\n@test app.plugins[:counter].count == app.tick_counter\nprintln(\"Tick count: $(app.plugins[:counter].count)\")\nprintln(\"Average cycle time: $(@sprintf(\"%.2f\", app.plugins[:perf].avg_elapsed)) nanoseconds, frequency: $(@sprintf(\"%.2f\", tickfreq(app.plugins[:perf]) / 1e6)) MHz\")","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"That was on the CI. On an i7 7700K I typically get around 19.95ns / 50.14 MHz. There is no overhead compared to a direct call of the manually merged tick() methods.","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"You can find this example under docs/examples/gettingstarted.jl if you check out the repo.","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"","category":"page"},{"location":"gettingstarted/","page":"Getting Started","title":"Getting Started","text":"This page was generated using Literate.jl.","category":"page"},{"location":"guide/#Guide","page":"Guide","title":"Guide","text":"","category":"section"},{"location":"guide/","page":"Guide","title":"Guide","text":"Here you will find a more in-depth example with","category":"page"},{"location":"guide/","page":"Guide","title":"Guide","text":"Lifecycle hooks\nStoring the hook cache in a type parameter for maximum performance (zero cost)\nModifying the plugin list while the app is \"running\"","category":"page"},{"location":"guide/","page":"Guide","title":"Guide","text":"The guide is not yet written. In the meantime you can check the tests, they cover every topic and they are named and organized in the hope that you will find them helpful.","category":"page"},{"location":"repo/#Repo","page":"Repo","title":"Repo","text":"","category":"section"},{"location":"repo/","page":"Repo","title":"Repo","text":"The sorce of the package can be found here: https://github.com/tisztamo/Plugins.jl","category":"page"},{"location":"features/#Features-and-usage","page":"Features and usage","title":"Features and usage","text":"","category":"section"},{"location":"features/#Good-work-starts-with-an-outline","page":"Features and usage","title":"Good work starts with an outline","text":"","category":"section"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"When using Plugins.jl, you split your system into two separated code domains: The base outlines the work to be done, and plugins fill out this outline with implementations. This pattern is widely used among large Julia packages[pkgsplit], because it helps coordinating developer work in a distributed fashion.","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"Plugins.jl extends this pattern with a coordination mechanism that allows multiple plugins to work together on the same task. This helps composing the system out of smaller, optional chunks, and also makes it easy to implement dynamic features like value-based message routing (aka dispatch on value) efficiently.","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"The coordination mechanism is very similar to how DOM event handlers work.","category":"page"},{"location":"features/#Hooks","page":"Features and usage","title":"Hooks","text":"","category":"section"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"A plugin implements so-called hooks: functions that the system will call at specific points of its inner life. You can think of hooks as they were event handlers, where the event source is the \"base system\". There are two types of hooks currently:","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"\"Lifecycle hooks\" are dynamically dispatched, and their results collected. Errors are also collected and do not interfere with other plugins.\n\"Normal hooks\" are designed for maximal runtime performance: When multiple plugins implement the same hook, their implementations will be merged together with simple glue code that allows any plugin to stop processing by simply returning true, similar to how DOM event handlers can stop event propagation. An error in a plugin also stops propagation.","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"This categorization will very likely be changed in a breaking way to allow better tuning of compilation overhead.","category":"page"},{"location":"features/#State","page":"Features and usage","title":"State","text":"","category":"section"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"Plugins can have their own state, and they can also access a shared state provided by the base system.","category":"page"},{"location":"features/#Configuration-injection","page":"Features and usage","title":"Configuration injection","text":"","category":"section"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"A \"global\" (per base system) configuration is passed to plugins during initialization, in the form of keyword arguments to the constructor. This means that plugins can specialize on the configuration, if performance requirements dictate that.","category":"page"},{"location":"features/#Dependency-injection","page":"Features and usage","title":"Dependency injection","text":"","category":"section"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"Plugins can declare other plugins as their mandantory dependencies. The system will analyse the dependency graph and initialize plugins accordingly. Just like configuration, dependencies are injected to the constructor.","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"Dependency declarations come in the form of types, e.g.:","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"Plugins.deps(::Type{Plugin3}) = [Plugin1, Plugin2]","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"Concrete types are concrete dependencies, while abstract types are used as \"interfaces\", meaning that any concrete subtype of the required abstract type can fulfill the dependency. The system will dynamically select implementations based on user configuration and specificity rules, allowing for example test mocking.","category":"page"},{"location":"features/#Ad-hoc-Inter-plugin-communication","page":"Features and usage","title":"Ad-hoc Inter-plugin communication","text":"","category":"section"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"Plugins can (informally) publish a runtime API for other plugins to use. To use the API, it is enough to know the symbol of the used plugin instead of its (super)type, which allows lightweight duck-typed interoperability: The \"user\" plugin asks the system for the plugin with a specific symbol, and calls its API. Symbols are defined by the type of the plugin, and should be unique among the instantiated plugins in a system.","category":"page"},{"location":"features/#Assembled-types:-Maintainable-runtime-metaprogramming","page":"Features and usage","title":"Assembled types: Maintainable runtime metaprogramming","text":"","category":"section"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"Additionally and optionally, the base system can define so-called assembled types. These are composite types that plugins will jointly assemble with every plugin allowed to delegate a single field.","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"This can help you with performance optimizations that normally would need @generated functions or other metaprograming. For example in the CircoCore.jl actor system (the reference application of Plugins.jl), plugins can extend the message type with data used to optimize routing. This is implemented with zero runtime cost, and without any metaprogramming in the plugin itself.","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"The plugin just declares the field it wants to add to an abstract type, and the base system will be instantiated with a concrete subtype which was generated to contain the field. The plugin then can access the field in hooks at its will, while other plugins will not know about it.","category":"page"},{"location":"features/","page":"Features and usage","title":"Features and usage","text":"[pkgsplit]: For example: Rackauckas, Chris & Nie, Qing. (2017). DifferentialEquations.jl – A Performant and Feature-Rich Ecosystem for Solving Differential Equations in Julia. Journal of Open Research Software. 5. 10.5334/jors.151.","category":"page"},{"location":"reference/#Reference","page":"Reference","title":"Reference","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"Modules = [Plugins]","category":"page"},{"location":"reference/#Plugins.Configuration","page":"Reference","title":"Plugins.Configuration","text":"abstract type Configuration <: ContextStage end\n\nStage that potentially changes the behavior of the program without evaluating previously unknown code.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.ContextStage","page":"Reference","title":"Plugins.ContextStage","text":"abstract type ContextStage <: Stage end\n\nStage technique that generates a new stage context type, which can be used for dispatching or in @generated functions. Assembled types may be regenerated during a ContextStage, depending on TODO.\n\nA context stage does not create a new world but run in the same world than the previous stage.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.EvalStage","page":"Reference","title":"Plugins.EvalStage","text":"abstract type EvalStage <: Stage end\n\nStage technique that runs in a new world and generates a new stage context type.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.Extension","page":"Reference","title":"Plugins.Extension","text":"abstract type Extension <: EvalStage end\n\nStage that evaluates previously unknown code, e.g. loads new plugins.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.FieldSpec","page":"Reference","title":"Plugins.FieldSpec","text":"FieldSpec(name, type::Type, constructor::Union{Function, DataType} = type)\n\nField specification for plugin-assembled types.\n\nNote that every field of an assembled type will be constructed with the same arguments.  Possibly The constructor will be called when the system \n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.HookList","page":"Reference","title":"Plugins.HookList","text":"HookList{TNext, THandler, TPlugin}\n\nProvides fast, inlinable call to the implementations of a specific hook.\n\nYou can get a HookList by calling hooklist() directly, or using hooks().\n\nThe HookList can be called with arbitrary number of extra arguments. If any of the plugins referenced in the list fails to handle the extra arguments, the call will raise a MethodError\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.ImmutableStruct","page":"Reference","title":"Plugins.ImmutableStruct","text":"struct ImmutableStruct <: TemplateStyle end\n\nPlugin-assembled types marked as ImmutableStruct will be generated as a struct.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.Initialization","page":"Reference","title":"Plugins.Initialization","text":"abstract type Initialization <: EvalStage end\n\nA classical Stage that runs before the normal operation of the program.\n\nMultiple initialization stages may run, but only before the first non-Initialization stage.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.MutableStruct","page":"Reference","title":"Plugins.MutableStruct","text":"struct MutableStruct <: TemplateStyle end\n\nPlugin-assembled types marked as MutableStruct will be generated as a mutable struct.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.Optimization","page":"Reference","title":"Plugins.Optimization","text":"abstract type Optimization <: ContextStage end\n\nStage that does not change the functional behavior of the program, only its performance characteristics.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.Plugin","page":"Reference","title":"Plugins.Plugin","text":"abstract type Plugin\n\nProvides default implementations of lifecycle hooks.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.PluginStack","page":"Reference","title":"Plugins.PluginStack","text":"PluginStack(plugins, hookfns = [])\n\nManages the plugins loaded into an application.\n\nIt provides fast access to the plugins by symbol, e.g. pluginstack[:logger]. Collection methods and iteration interface are implemented.\n\nThe pluginstack is created from a list of plugins, and optionally a list of hook functions. If hook functions are provided, the hooks()` function can be called to\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.Stage","page":"Reference","title":"Plugins.Stage","text":"abstract type Stage end\n\nBase type that represents a step of iterated staging.\n\nIterated staging allows the program to repeatedly self-recompile its parts. The first iterations are\n\nStage is the root of a layered type hierarchy:\n\nDirect subtypes of it (ContextStage, EvalStage) represent staging\n\ntechniques available in Julia.\n\nDownstream subtypes represent means of staging:\n\nInitialization, Extension, Optimization, Configuration.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Plugins.TemplateStyle-Tuple{Type}","page":"Reference","title":"Plugins.TemplateStyle","text":"TemplateStyle(::Type) = MutableStruct()\n\nTrait to select the template used for plugin-assembled types\n\nUse MutableStruct (default), ImmutableStruct, or subtype it when you want to create your own template.\n\n#Examples\n\nAssembling immutable structs:\n\nabstract type DebugInfo end\nPlugins.TemplateStyle(::Type{DebugInfo}) = Plugins.ImmutableStruct()\n\nDefining your own template (see also  typedef ):\n\nstruct CustomTemplate <: Plugins.TemplateStyle end\nPlugins.TemplateStyle(::Type{State}) = CustomTemplate()\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.autoregister","page":"Reference","title":"Plugins.autoregister","text":"function autoregister(base=Plugin)\n\nFind and register every concrete subtype of 'base' as a Plugin\n\n\n\n\n\n","category":"function"},{"location":"reference/#Plugins.customfield-Tuple{Plugin, Type, Vararg{Any}}","page":"Reference","title":"Plugins.customfield","text":"customfield(plugin::Plugin, abstract_type::Type, args...) = nothing\n\nProvide field specifications to plugin-assembled types.\n\nUsing this lifecycle hook the system can define custom plugin-assembled types (typically structs) based on field specifications provided by plugins. E.g. an error type can be extended with debug information.\n\nA plugin can provide zero or one field to every assembled type. To provide a field, return a FieldSpec.\n\nThe assembled type will be a subtype of abstract_type. To allow differently configured systems to run in the same Julia session, new types may be assembled for every instance of the system.\n\nwarning: Metaprogramming may make you unhappy\nAlthough plugin-assmebled types are designed to help doing metaprogramming in a controlled fashion, it is usually better to use non-meta solutions instead. E.g. Store plugin state inside the plugin, collect data from multiple plugins using lifecycle hooks, etc.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.customtype","page":"Reference","title":"Plugins.customtype","text":"customtype(stack::PluginStack, typename::Symbol, abstract_type::Type, target_module::Module = Main; unique_name = true)\n\nAssemble a type with fields provided by the plugins in stack.\n\nabstract_type will be the supertype of the assembled type.\n\nIf unique_name == true, then typename will be suffixed with a structure-dependent id. The  id is generated as a hash of the evaluated expression (with the :TYPE_NAME placeholder used instead of the name), meaning that for the same id will be generated for a given type when the same plugins with the same source code are loaded.\n\nExamples\n\nAssembling a type AppStateImpl <: AppState and parametrizing the app with it. \n\nabstract type AppState end\n\nmutable struct CustomFieldsApp{TCustomState}\n    state::TCustomState\n    function CustomFieldsApp(plugins, hookfns, stateargs...)\n        stack = PluginStack(plugins, hookfns)\n        state_type = customtype(stack, :AppStateImpl, AppState)\n        return new{state_type}(Base.invokelatest(state_type, stateargs...))\n    end\nend\n\nnote: The need for `invokelatest`\nWe need to use invokelatest to instantiate a newly generated type. To use  the generated type normally, first you have to allow control flow to go to the top-level scope after the type was generated. See also the docs\n\nwarning: Antipattern\nAssembling state types is an antipattern, because plugins can have their own state. (This may provide better performance in a few cases though) Assembled types can make your code less readable, use them sparingly!\n\n\n\n\n\n","category":"function"},{"location":"reference/#Plugins.deps-Tuple{Any}","page":"Reference","title":"Plugins.deps","text":"Plugins.deps(::Type{T}) = Type[] # where T is your plugin type\n\nAdd a method to declare your dependencies.\n\nThe plugin type must have a constructor accepting an instance of every of their dependencies.\n\nExamples\n\nabstract type InterfaceLeft end struct ImplLeft <: InterfaceLeft end\n\nabstract type InterfaceRight end struct ImplRight <: InterfaceRight end\n\nPlugins.deps(::Type{ImplLeft}) = [ImplRight]\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.enter_stage-Tuple{Plugin, Any, Vararg{Any}}","page":"Reference","title":"Plugins.enter_stage","text":"enter_stage(plugin::Plugin, stage::Stage, args...)\n\nLifecycle hook marking the start of the next stage.\n\nTypes are reasssembled at this point. If stage isa EvalStage, then the world is already updated. (execution reached toplevel)\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.hook_cache-Tuple{Any, Any}","page":"Reference","title":"Plugins.hook_cache","text":"hook_cache(stack::PluginStack, hookfns)\nhook_cache(plugins, hookfns)\n\nCreate a cache of HookLists for a PluginStack or from lists of plugins and hook functions.\n\nReturns a NamedTuple with an entry for every handler.\n\nExamples\n\ncache = hook_cache([Plugin1(), Plugin2()], [hook1, hook2])\ncache.hook1()\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.hooklist-Tuple{Any, Any}","page":"Reference","title":"Plugins.hooklist","text":"function hooklist(plugins, hookfn)\n\nCreate a HookList which allows fast, inlinable call to the merged implementations of hookfn by the given plugins.\n\nA plugin of type TPlugin found in plugins will be referenced in the resulting HookList if there is a method that matches the following signature: hookfn(::TPlugin, ...)\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.hooks","page":"Reference","title":"Plugins.hooks","text":"hooks(app)\nhooks(pluginstack::PluginStack)\n\nCreate or get a hook cache for stack.\n\nThe first form can be used when pluginstack is stored in app.plugins (the recommended pattern).\n\nWhen this function is called first time on a PluginStack, the hooks cache will be created by calling hook_cache(), and stored in pluginstack for quick access later.\n\n\n\n\n\n","category":"function"},{"location":"reference/#Plugins.leave_stage-Tuple{Plugin, Any, Vararg{Any}}","page":"Reference","title":"Plugins.leave_stage","text":"leave_stage(plugin::Plugin, stage::Stage, nextstage::Stage, args...)\n\nLifecycle hook marking the end of a stage.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.prepare_stage-Tuple{Plugin, Any, Vararg{Any}}","page":"Reference","title":"Plugins.prepare_stage","text":"prepare_stage(plugin::Plugin, stage::Stage)\n\nLifecycle hook to prepare the plugin for the next stage. If the stage is an EvalStage and the plugin needs to evaluate code, this is the point to do it.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.request_stage-Tuple{Plugin, Vararg{Any}}","page":"Reference","title":"Plugins.request_stage","text":"request_stage(plugin::Plugin, args...)::Stage\n\nRequest a new stage iteration by returning a Stage representing it.\n\nThis lifecycle hook will be called repeatedly to ask plugins their wish to stage. If a plugin returns a Stage instance and the request is accepted, the stage will start immediately.\n\nIf more than one plugins ask for staging, their request will be merged if possible and only one stage will run. If the stages are incompatible, meaning that different sets of plugins handle the prepeare hook of the stages, then only a compatible subset of them will run.\n\nPlugins should continue requesting staging until their wish gets fulfilled.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.setup!-Tuple{Plugin, Vararg{Any}}","page":"Reference","title":"Plugins.setup!","text":"setup!(plugin, deps, args...)\n\nInitialize the plugin with the given dependencies and arguments (e.g. shared state).\n\nThis lifecycle hook will be called when the application loads a plugin. Plugins.jl does not (yet) helps with this, application developers should do it manually, right after the PluginStack was created, before the hook_cache() call.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.shutdown!-Tuple{Plugin, Vararg{Any}}","page":"Reference","title":"Plugins.shutdown!","text":"shutdown!(plugin, args...)\n\nShut down the plugin.\n\nThis lifecycle hook will be called when the application unloads a plugin, e.g. before the application exits. Plugins.jl does not (yet) helps with this, application developers should do it manually.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.symbol-Tuple{Plugin}","page":"Reference","title":"Plugins.symbol","text":"symbol(plugin)\n\nReturn the per-PluginStack unique Symbol of this plugin if it exports a \"late-bind\" runtime API to other plugins.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Plugins.typedef","page":"Reference","title":"Plugins.typedef","text":"typedef(templatestyle, spec::TypeSpec)::Expr\n\nReturn an expression defining a type.\n\nImplement it for your own template styles. More info in the tests.\n\n\n\n\n\n","category":"function"},{"location":"#Introduction","page":"Introduction","title":"Introduction","text":"","category":"section"},{"location":"#Modules-on-steroids","page":"Introduction","title":"Modules on steroids","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Plugins.jl:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Shapes your code by helping to implement the popular \"extensions\" architectural pattern.\nProvides dependency management/injection for more declarative code structuring and easier testing.\nZero Cost Abstraction: Plugin code is inlinable. You've read it right: inlinable.\nAllows maintainable runtime metaprogramming in a controlled way that prevents meta code from taking over your codebase.\nDefines a standard plugin lifecycle (sort of).","category":"page"},{"location":"#What-plugins-are-in-general?","page":"Introduction","title":"What plugins are in general?","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Feel free to skip this section if you know the answer.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"A plugin is a chunk of code that extends the functionality of a system. It is not usable in itself, it has to be \"plugged\" into a system where it reacts to events and works together with other plugins. Plugins are sometimes called \"extensions\", and they can be found everywhere: from IDEs to browsers, from music software to operating systems.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"A software built with plugins is like a kitchen where different devices work together to help you. When you want to drink some tea, you will need a cup so that you can boil water in the microwave. If you drink a lot of tea, you may buy and plug in a kettle, beacuse that is better for boiling water. A good cup can work together with both the micro and the kettle, and you don't have to throw out your micro, you can still warm up your food with it.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Now, abstractions in programming can do something like this: to help replacing implementations by separating interface from implementation.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Plugins provide the highest level abstraction layer of a system. This level is ideally so flexible that the user can easily replace parts of the system without programming, maybe even at runtime. You install a plugin and it just works.","category":"page"},{"location":"#The-performance-problem","page":"Introduction","title":"The performance problem","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"The plugin-based architecture is a popular way to develop maintainable and extensible software, but its dynamic nature introduces a performance penalty that is not always acceptable. You tipically cannot hook into performance-critical points.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Plugins.jl helps by analyzing the plugins loaded into the system and generating efficient, statically dispatched event handling code, thus allowing full optimization.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"With Plugins.jl, execution of plugin code can be just as performant as a manually composed system. Inlinable hook implementations will be merged into a single function body, and non-implementing plugins are skipped with zero overhead.","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"EditURL = \"<unknown>/docs/examples/gettingstarted.jl\"","category":"page"},{"location":"tutorial/#Tutorial","page":"Tutorial","title":"Tutorial","text":"","category":"section"},{"location":"tutorial/#Motivation","page":"Tutorial","title":"Motivation","text":"","category":"section"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"Let's say you are writing a lib which performs some work in a loop quickly (up to several million times per second). You need to allow your users to monitor this loop, but the requirements vary: One user just wants to count the total number of cycles, another wants to measure the performance and write some metrics to a file regularly, etc. The only requirement that everybody has is maximum performance.","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"Maybe you also have an item on your wishlist: To allow your less techie users to configure the monitoring without coding. Sometimes you even dream of reconfiguring the monitoring while the app is running...","category":"page"},{"location":"tutorial/#Installation","page":"Tutorial","title":"Installation","text":"","category":"section"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"The package is registered, so simply: julia> using Pkg; Pkg.add(\"Plugins\"). (repo)","category":"page"},{"location":"tutorial/#Your-first-and-second-plugins","page":"Tutorial","title":"Your first and second plugins","text":"","category":"section"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"The first one simply counts the calls to the tick() hook.","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"using Plugins, Printf, Test\n\nmutable struct CounterPlugin <: Plugin\n    count::UInt\n    CounterPlugin() = new(0)\nend\n\nPlugins.symbol(::CounterPlugin) = :counter # For access from the outside / from other plugins\nPlugins.register(CounterPlugin)\n\nfunction tick(me::CounterPlugin, app)\n    me.count += 1\nend;\nnothing #hide","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"The second will measure the frequency of tick() calls:","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"mutable struct PerfPlugin <: Plugin\n    last_call_ts::UInt64\n    avg_elapsed::Float32\n    PerfPlugin() = new(time_ns(), 0)\nend\n\nPlugins.symbol(::PerfPlugin) = :perf\nPlugins.register(PerfPlugin)\n\n\ntickfreq(me::PerfPlugin) = 1e9 / me.avg_elapsed;\nnothing #hide","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"When the tick() hook is called, it calculates the time difference to the stored timestamp of the last call, and updates the exponential moving average:","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"const alpha = 1.0f-3\n\nfunction tick(me::PerfPlugin, app)\n    ts = time_ns()\n    diff = ts - me.last_call_ts\n    me.last_call_ts = ts\n    me.avg_elapsed = alpha * Float32(diff) + (1.0f0 - alpha) * me.avg_elapsed\nend;\nnothing #hide","category":"page"},{"location":"tutorial/#The-application","page":"Tutorial","title":"The application","text":"","category":"section"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"Now let's create the base system. Its state holds the plugins and a counter (just to cross-check the CounterPlugin):","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"mutable struct App\n    plugins::PluginStack\n    tick_counter::UInt\n    App(plugins, hookfns) = new(PluginStack(plugins, hookfns), 0)\nend","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"There is a single operation on the app, which increments the tick_counter in a cycle and calls the tick() hook:","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"function tickerop(app::App)\n    tickhook = hooks(app).tick\n    tickerop_kern(app, tickhook) # Using a function barrier to get ~5ns per hook activation\nend\n\nfunction tickerop_kern(app::App, tickhook)\n    for i = 1:1e6\n        app.tick_counter += 1\n        tickhook(app) # We can pass shared state to plugins on the hook. Here, for simplicity, the whole app.\n    end\nend;\nnothing #hide","category":"page"},{"location":"tutorial/#Running-it","page":"Tutorial","title":"Running it","text":"","category":"section"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"The last step is to initialize the app, call the operation, and read out the performance measurement from the plugins:","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"app = App([CounterPlugin, PerfPlugin], [tick])\ntickerop(app)\n\n@test app.plugins[:counter].count == app.tick_counter\nprintln(\"Tick count: $(app.plugins[:counter].count)\")\nprintln(\"Average cycle time: $(@sprintf(\"%.2f\", app.plugins[:perf].avg_elapsed)) nanoseconds, frequency: $(@sprintf(\"%.2f\", tickfreq(app.plugins[:perf]) / 1e6)) MHz\")","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"That was on the CI. On an i7 7700K I typically get around 19.95ns / 50.14 MHz. There is no overhead compared to a direct call of the manually merged tick() methods.","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"You can find this example under docs/examples/gettingstarted.jl if you check out the repo.","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"","category":"page"},{"location":"tutorial/","page":"Tutorial","title":"Tutorial","text":"This page was generated using Literate.jl.","category":"page"}]
}
