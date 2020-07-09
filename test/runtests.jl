using Plugins
import Plugins.symbol, Plugins.setup!, Plugins.setup!
using Test

struct Framework
    plugins
    Framework(plugins) = new(PluginStack(plugins))
end

struct EmptyPlugin <: Plugin
end

mutable struct CounterPlugin <: Plugin
    hook1count::Int
    hook2count::Int
    CounterPlugin() = new(0, 0)
end
symbol(::CounterPlugin) = :counter
@inline hook1(plugin::CounterPlugin, framework) = begin
    plugin.hook1count += 1
    return false
end

hook2_handler(plugin::CounterPlugin, framework) = begin
    plugin.hook2count += 1
    return false
end

chain_of_empties(length=20) = [EmptyPlugin() for i = 1: length]

callmanytimes(hook, times=1e5) = for i=1:times hook() end

mutable struct FrameworkTestPlugin <: Plugin
    calledwithframework
    FrameworkTestPlugin() = new("Never called")
end
hook1(plugin::FrameworkTestPlugin, framework) = plugin.calledwithframework = framework

mutable struct EventTestPlugin <: Plugin
    calledwithframework
    calledwithevent
    EventTestPlugin() = new("Never called", "Never called")
end
event_handler(plugin::EventTestPlugin, framework, event) = begin
    plugin.calledwithframework = framework
    plugin.calledwithevent = event
end

struct ConfigurablePlugin <: Plugin
    config::String
    ConfigurablePlugin(config::String = "default") = new(config)
end
checkconfig_handler(plugin::ConfigurablePlugin, framework, event) = begin
    if event.config !== plugin.config
        throw("Not the same!")
    end
end

struct PropagationStopperPlugin <: Plugin
end
propagationtest(plugin::PropagationStopperPlugin, framework, data) = data == 42
propagationtest_nodata(plugin::PropagationStopperPlugin, framework) = true

struct PropagationCheckerPlugin <: Plugin
end
propagationtest(plugin::PropagationCheckerPlugin, framework, data) = data === 32 || throw("Not 32!")
propagationtest_nodata(plugin::PropagationCheckerPlugin, framework) = throw("Not stopped!")

mutable struct DynamicPlugin <: Plugin
    lastdata
end
dynamismtest(plugin::DynamicPlugin, framework, data) = plugin.lastdata = data


# Hook cache test:
mutable struct SharedState
    plugins::PluginStack
    shared_counter::Int
end

struct App{TCache}
    state::SharedState
    hooks::TCache
    function App(plugins, hooklist)
        state = SharedState(PluginStack(plugins), 0)
        cache = hook_cache(hooklist, state)
        return new{typeof(cache)}(state, cache)
    end
end

const OP_CYCLES = 1e7

function op(app::App)
    counters = [counter for counter in app.state.plugins if counter isa CounterPlugin]
    @info "op: A sample operation on the app, involving hook1() calls in a semi-realistic setting."
    @info "op: $(length(counters)) CounterPlugins found, $(length(app.state.plugins)) plugins in total, each CounterPlugin incrementing a private counter."

    start_hook1count = app.state.shared_counter
    
    start_ts = time_ns()
    for i in 1:OP_CYCLES
        app.hooks.hook1()
    end
    end_ts = time_ns()

    for i = 1:length(counters)
        @test counters[i].hook1count == OP_CYCLES
    end

    time_diff = end_ts - start_ts
    avg_calltime = time_diff / OP_CYCLES
    @info "op: $OP_CYCLES hook1() calls took $(time_diff / 1e9) secs. That is $avg_calltime nanosecs per call on average, or $(avg_calltime / length(counters)) ns per in-plugin counter increment."
end

mutable struct LifeCycleTestPlugin <: Plugin
    setupcalledwith
    shutdowncalledwith
    deferredinitcalledwith
    LifeCycleTestPlugin() = new()
end
Plugins.setup!(plugin::LifeCycleTestPlugin, framework) = plugin.setupcalledwith = framework
Plugins.shutdown!(plugin::LifeCycleTestPlugin, framework) = begin
    plugin.shutdowncalledwith = framework
    if framework === 42
        throw("shutdown called with 42")
    end
end
deferred_init(plugin::Plugin, ::Any) = true
deferred_init(plugin::LifeCycleTestPlugin, data) = plugin.deferredinitcalledwith = data

@testset "Plugins.jl" begin
    @testset "Plugin chain" begin
        innerplugin = EmptyPlugin()
        counter = CounterPlugin()
        a1 = Framework([counter, innerplugin])
        a1_hook1s = hooklist(a1, hook1)
        @test length(a1_hook1s) === 1
        callmanytimes(a1_hook1s)
        @info "$(length(a1.plugins))-length chain, $(length(a1_hook1s)) counter (1e5 cycles):"
        @time callmanytimes(a1_hook1s)
        hooklist(a1, hook2_handler)()
        @test counter.hook1count == 2e5
        @test counter.hook2count == 1
    end

    @testset "Same plugin twice" begin
        innercounter = CounterPlugin()
        outercounter = CounterPlugin()
        a2 = Framework([outercounter, innercounter])
        a2_hook1s = hooklist(a2, hook1)
        @test length(a2_hook1s) === 2
        callmanytimes(a2_hook1s)
        @info "$(length(a2.plugins))-length chain, $(length(a2_hook1s)) counters (1e5 cycles):"
        @time callmanytimes(a2_hook1s)
        hooklist(a2, hook2_handler)()
        @test innercounter.hook1count == 2e5
        @test innercounter.hook2count == 1
        @test outercounter.hook1count == 2e5
        @test outercounter.hook2count == 1
    end

    @testset "Chain of empty Plugins to eliminate" begin
        innerplugin = CounterPlugin()
        outerplugin = CounterPlugin()
        chainedapp = Framework(vcat([outerplugin], chain_of_empties(), [innerplugin], chain_of_empties()))
        chainedapp_hook1s = hooklist(chainedapp, hook1)
        callmanytimes(chainedapp_hook1s)
        @info "$(length(chainedapp.plugins))-length chain,  $(length(chainedapp_hook1s))  counters (1e5 cycles):"
        @time callmanytimes(chainedapp_hook1s)
        @test outerplugin.hook1count == 2e5
        @test outerplugin.hook2count == 0
        @test innerplugin.hook1count == 2e5
        @test innerplugin.hook2count == 0
    end

    @testset "Unhandled hook returns false" begin
        app = Framework([EmptyPlugin()])
        @test hooklist(app, hook1)() == false
    end

    @testset "Framework goes through" begin
        frameworktestapp = Framework([EmptyPlugin(), FrameworkTestPlugin()])
        hooklist(frameworktestapp, hook1)()
        @test frameworktestapp.plugins[2].calledwithframework === frameworktestapp
    end

    @testset "Event object" begin
        eventtestapp = Framework([EmptyPlugin(), EventTestPlugin()])
        event = (name="test event", data=42)
        hooklist(eventtestapp, event_handler)(event)
        @test eventtestapp.plugins[2].calledwithframework === eventtestapp
        @test eventtestapp.plugins[2].calledwithevent === event
    end

    @testset "Multiple apps with same chain, differently configured" begin
        app2config = "app2config"
        app1 = Framework([EmptyPlugin(), ConfigurablePlugin()])
        app2 = Framework([EmptyPlugin(), ConfigurablePlugin(app2config)])
        event1 = (config ="default",)
        event2 = (config = app2config,)
        hooklist(app1, checkconfig_handler)(event1)
        @test_throws String hooklist(app1, checkconfig_handler)(event2)
        hooklist(app2, checkconfig_handler)(event2)
        @test_throws String hooklist(app2, checkconfig_handler)(event1)
    end

    @testset "Stopping Propagation" begin
        spapp = Framework([EmptyPlugin(), PropagationStopperPlugin(), EmptyPlugin(), PropagationCheckerPlugin()])
        hooklist(spapp, propagationtest)(42) === true # It is stopped so the checker does not throw
        hooklist(spapp, propagationtest)(32) === false # Not stopped but accepted by the checker
        @test_throws String hooklist(spapp, propagationtest)(41)

        @test hooklist(spapp, propagationtest_nodata)() === true
    end

    @testset "HookList iteration" begin
        c1 = CounterPlugin()
        c2 = CounterPlugin()
        hookers = [c2, c1]
        iapp = Framework([EmptyPlugin(), c2, EmptyPlugin(), c1, EmptyPlugin()])
        @test length(hooklist(iapp, hook1)) === 2
        i = 1
        for hook in hooklist(iapp, hook1)
            @test hookers[i] === hook.plugin
            i += 1
        end
    end

    @testset "Accessing plugins directly" begin
        empty = EmptyPlugin()
        counter = CounterPlugin()
        app = Framework([empty, counter])
        @test app.plugins[1] === empty
        @test app.plugins[2] === counter
        @test get(app.plugins, :nothing) === empty
        @test get(app.plugins, :counter) === counter
        @test app.plugins[:nothing] === empty
        @test length(app.plugins) == 2
    end

    @testset "Hook cache" begin
        firstcounter = CounterPlugin()
        counters = [CounterPlugin() for i=1:30]
        empties = [EmptyPlugin() for i=1:1000]

        simpleapp = SharedState(PluginStack([firstcounter, empties..., counters...], [hook1]), 0)
        simpleapp_hooks = hooks(simpleapp)
        simpleapp_hooks.hook1()
        @test firstcounter.hook1count == 1
    end

    @testset "Hook cache as type parameter" begin
        firstcounter = CounterPlugin()
        counters = [CounterPlugin() for i=1:30]
        empties = [EmptyPlugin() for i=1:1000]
        app = App([firstcounter, empties..., counters...], [hook1])
        op(app)
    end

    @testset "Lifecycle Hooks" begin
        plugin = LifeCycleTestPlugin()
        app = Framework([EmptyPlugin(), plugin])
        @test setup!(app.plugins, app).allok == true
        @test plugin.setupcalledwith === app

        # Create a non-standard lifecycle hook
        lifecycle_hook = Plugins.create_lifecyclehook(deferred_init)
        @test lifecycle_hook(app.plugins, "42").allok === true
        @test plugin.deferredinitcalledwith === "42"

        @test shutdown!(app.plugins, app).allok === true
        @test plugin.shutdowncalledwith === app
        @test shutdown!(app.plugins, 42).allok === false
        @test plugin.shutdowncalledwith === 42
    end
end
