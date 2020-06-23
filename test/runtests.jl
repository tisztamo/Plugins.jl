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
@inline hook1_handler(plugin::CounterPlugin, framework) = begin
    plugin.hook1count += 1
    return false
end

hook2_handler(plugin::CounterPlugin, framework) = begin
    plugin.hook2count += 1
    return false
end

chain_of_empties(length=20) = [EmptyPlugin() for i = 1: length]

mutable struct FrameworkTestPlugin <: Plugin
    calledwithframework
    FrameworkTestPlugin() = new("Never called")
end
hook1_handler(plugin::FrameworkTestPlugin, framework) = plugin.calledwithframework = framework

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
        a1_hook1s = hooks(a1, hook1_handler)
        @test length(a1_hook1s) === 1
        for i=1:1e5 a1_hook1s() end
        @time for i=1:1e5 a1_hook1s() end
        hooks(a1, hook2_handler)()
        @test counter.hook1count == 2e5
        @test counter.hook2count == 1
    end

    @testset "Same plugin twice" begin
        innercounter = CounterPlugin()
        outercounter = CounterPlugin()
        a2 = Framework([outercounter, innercounter])
        a2_hook1s = hooks(a2, hook1_handler)
        @test length(a2_hook1s) === 2
        for i=1:1e5 a2_hook1s() end
        @time for i=1:1e5 a2_hook1s() end
        hooks(a2, hook2_handler)()
        @test innercounter.hook1count == 2e5
        @test innercounter.hook2count == 1
        @test outercounter.hook1count == 2e5
        @test outercounter.hook2count == 1
    end

    @testset "Chain of empty Plugins to eliminate" begin
        innerplugin = CounterPlugin()
        outerplugin = CounterPlugin()
        chainedapp = Framework(vcat([outerplugin], chain_of_empties(), [innerplugin], chain_of_empties()))
        chainedapp_hook1s = hooks(chainedapp, hook1_handler)
        for i=1:1e5 chainedapp_hook1s() end
        @time for i=1:1e5 chainedapp_hook1s() end
        @test outerplugin.hook1count == 2e5
        @test outerplugin.hook2count == 0
        @test innerplugin.hook1count == 2e5
        @test innerplugin.hook2count == 0
    end

    @testset "Framework goes through" begin
        frameworktestapp = Framework([EmptyPlugin(), FrameworkTestPlugin()])
        hooks(frameworktestapp, hook1_handler)()
        @test frameworktestapp.plugins[2].calledwithframework === frameworktestapp
    end

    @testset "Event object" begin
        eventtestapp = Framework([EmptyPlugin(), EventTestPlugin()])
        event = (name="test event", data=42)
        hooks(eventtestapp, event_handler)(event)
        @test eventtestapp.plugins[2].calledwithframework === eventtestapp
        @test eventtestapp.plugins[2].calledwithevent === event
    end

    @testset "Multiple apps with same chain, differently configured" begin
        app2config = "app2config"
        app1 = Framework([EmptyPlugin(), ConfigurablePlugin()])
        app2 = Framework([EmptyPlugin(), ConfigurablePlugin(app2config)])
        event1 = (config ="default",)
        event2 = (config = app2config,)
        hooks(app1, checkconfig_handler)(event1)
        @test_throws String hooks(app1, checkconfig_handler)(event2)
        hooks(app2, checkconfig_handler)(event2)
        @test_throws String hooks(app2, checkconfig_handler)(event1)
    end

    @testset "Stopping Propagation" begin
        spapp = Framework([EmptyPlugin(), PropagationStopperPlugin(), EmptyPlugin(), PropagationCheckerPlugin()])
        hooks(spapp, propagationtest)(42) === true # It is stopped so the checker does not throw
        hooks(spapp, propagationtest)(32) === false # Not stopped but accepted by the checker
        @test_throws String hooks(spapp, propagationtest)(41)

        @test hooks(spapp, propagationtest_nodata)() === true
    end

    @testset "HookList iteration" begin
        c1 = CounterPlugin()
        c2 = CounterPlugin()
        hookers = [c2, c1]
        iapp = Framework([EmptyPlugin(), c2, EmptyPlugin(), c1, EmptyPlugin()])
        @test length(hooks(iapp, hook1_handler)) === 2
        i = 1
        for hook in hooks(iapp, hook1_handler)
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
