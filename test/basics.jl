
struct Framework
    plugins
    Framework(plugins, hooks=[]; opts...) = new(PluginStack(plugins, hooks; opts...))
end

struct EmptyPlugin{Id} <: Plugin
    EmptyPlugin{Id}(;opts...) where Id = new{Id}()
end
Plugins.symbol(::EmptyPlugin) = :empty
for i = 1:1000
    Plugins.register(EmptyPlugin{i})
end

mutable struct CounterPlugin{Id} <: Plugin
    hook1count::Int
    hook2count::Int
    hook3count::Int
    CounterPlugin{Id}() where Id = new{Id}(0, 0, 0)
end
Plugins.symbol(::CounterPlugin) = :counter
for i = 1:100
    Plugins.register(CounterPlugin{i})
end

@inline hook1(plugin::CounterPlugin, framework) = begin
    plugin.hook1count += 1
    return false
end

hook2_handler(plugin::CounterPlugin, framework) = begin
    plugin.hook2count += 1
    return false
end

@inline hook3(plugin::CounterPlugin, framework, p1, p2) = begin
    plugin.hook3count += p2
    return false
end

chain_of_empties(length=20, startat=0) = [EmptyPlugin{i + startat} for i = 1:length]

callmanytimes(framework, hook, times=1e5) = for i=1:times hook(framework) end

mutable struct FrameworkTestPlugin <: Plugin
    calledwithframework
    FrameworkTestPlugin() = new("Never called")
end
Plugins.register(FrameworkTestPlugin)
hook1(plugin::FrameworkTestPlugin, framework) = plugin.calledwithframework = framework

mutable struct EventTestPlugin <: Plugin
    calledwithframework
    calledwithevent
    EventTestPlugin() = new("Never called", "Never called")
end
Plugins.register(EventTestPlugin)
event_handler(plugin::EventTestPlugin, framework, event) = begin
    plugin.calledwithframework = framework
    plugin.calledwithevent = event
end

struct ConfigurablePlugin <: Plugin
    config::String
    ConfigurablePlugin(;config = "default") = new(config)
end
Plugins.register(ConfigurablePlugin)
checkconfig_handler(plugin::ConfigurablePlugin, framework, event) = begin
    if event.config !== plugin.config
        throw("Not the same!")
    end
end

struct PropagationStopperPlugin <: Plugin
end
Plugins.register(PropagationStopperPlugin)
propagationtest(plugin::PropagationStopperPlugin, framework, data) = data == 42
propagationtest_nodata(plugin::PropagationStopperPlugin, framework) = true

struct PropagationCheckerPlugin <: Plugin
end
Plugins.register(PropagationCheckerPlugin)
propagationtest(plugin::PropagationCheckerPlugin, framework, data) = data === 32 || throw("Not 32!")
propagationtest_nodata(plugin::PropagationCheckerPlugin, framework) = throw("Not stopped!")

mutable struct DynamicPlugin <: Plugin
    lastdata
end
Plugins.register(DynamicPlugin)
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
        state = SharedState(PluginStack(plugins, hooklist), 0)
        cache = hook_cache(state.plugins)
        return new{typeof(cache)}(state, cache)
    end
end

const OP_CYCLES = 1e7

function op(app::App)
    counters = [counter for counter in app.state.plugins if counter isa CounterPlugin]
    @info "op: A sample operation on the app, involving hook1() calls in a semi-realistic setting."
    @info "op: $(length(counters)) CounterPlugins found, $(length(app.state.plugins)) plugins in total, each CounterPlugin incrementing a private counter."

    start_ts = time_ns()
    for i in 1:OP_CYCLES
        app.hooks.hook3(app, i, 1)
    end
    end_ts = time_ns()

    for i = 1:length(counters)
        @test counters[i].hook3count == OP_CYCLES
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
Plugins.register(LifeCycleTestPlugin)
Plugins.setup!(plugin::LifeCycleTestPlugin, framework) = plugin.setupcalledwith = framework
Plugins.shutdown!(plugin::LifeCycleTestPlugin, framework) = begin
    plugin.shutdowncalledwith = framework
    if framework === 42
        error("shutdown called with 42")
    end
end
deferred_init(plugin::Plugin, ::Any) = true
deferred_init(plugin::LifeCycleTestPlugin, data) = plugin.deferredinitcalledwith = data

@testset "Plugins.jl basics" begin
    @testset "Plugin chain" begin
        a1 = Framework([CounterPlugin{1}, EmptyPlugin])
        @show innerplugin = a1.plugins[:empty]
        @show counter = a1.plugins[:counter]
        a1_hook1s = hooklist(a1.plugins, hook1)
        @test length(a1_hook1s) === 1
        callmanytimes(a1, a1_hook1s)
        @info "$(length(a1.plugins))-length chain, $(length(a1_hook1s)) counter (1e5 cycles):"
        @time callmanytimes(a1, a1_hook1s)
        hooklist(a1.plugins, hook2_handler)(a1)
        @test counter.hook1count == 2e5
        @test counter.hook2count == 1
    end

    @testset "Same plugin twice" begin
        a2 = Framework([CounterPlugin{1}, CounterPlugin{2}])
        innercounter = a2.plugins[2]
        outercounter = a2.plugins[1]
        a2_hook1s = hooklist(a2.plugins, hook1)
        @test length(a2_hook1s) === 2
        callmanytimes(a2, a2_hook1s)
        @info "$(length(a2.plugins))-length chain, $(length(a2_hook1s)) counters (1e5 cycles):"
        @time callmanytimes(a2, a2_hook1s)
        hooklist(a2.plugins, hook2_handler)(a2)
        @test innercounter.hook1count == 2e5
        @test innercounter.hook2count == 1
        @test outercounter.hook1count == 2e5
        @test outercounter.hook2count == 1
    end

    @testset "Chain of empty Plugins to skip" begin
        chainedapp = Framework(vcat([CounterPlugin{1}], chain_of_empties(20), [CounterPlugin{2}], chain_of_empties(20, 21)))
        innerplugin = chainedapp.plugins[22]
        outerplugin = chainedapp.plugins[1]
        chainedapp_hook1s = hooklist(chainedapp.plugins, hook1)
        callmanytimes(chainedapp, chainedapp_hook1s)
        @info "$(length(chainedapp.plugins))-length chain,  $(length(chainedapp_hook1s))  counters (1e5 cycles):"
        @time callmanytimes(chainedapp, chainedapp_hook1s)
        @test outerplugin.hook1count == 2e5
        @test outerplugin.hook2count == 0
        @test innerplugin.hook1count == 2e5
        @test innerplugin.hook2count == 0
    end

    @testset "Unhandled hook returns false" begin
        app = Framework([EmptyPlugin{1}])
        @test hooklist(app.plugins, hook1)() == false
    end

    @testset "Framework goes through" begin
        frameworktestapp = Framework([EmptyPlugin{1}, FrameworkTestPlugin])
        hooklist(frameworktestapp.plugins, hook1)(frameworktestapp)
        @test frameworktestapp.plugins[2].calledwithframework === frameworktestapp
    end

    @testset "Event object" begin
        eventtestapp = Framework([EmptyPlugin{1}, EventTestPlugin])
        event = (name="test event", data=42)
        hooklist(eventtestapp.plugins, event_handler)(eventtestapp, event)
        @test eventtestapp.plugins[2].calledwithframework === eventtestapp
        @test eventtestapp.plugins[2].calledwithevent === event
    end

    @testset "Multiple apps with same chain, differently configured" begin
        app2config = "app2config"
        app1 = Framework([EmptyPlugin{1}, ConfigurablePlugin])
        app2 = Framework([EmptyPlugin{2}, ConfigurablePlugin]; config=app2config)
        event1 = (config ="default",)
        event2 = (config = app2config,)
        hooklist(app1.plugins, checkconfig_handler)(app1, event1)
        @test_throws String hooklist(app1.plugins, checkconfig_handler)(app1, event2)
        hooklist(app2.plugins, checkconfig_handler)(app2, event2)
        @test_throws String hooklist(app2.plugins, checkconfig_handler)(app2, event1)
    end

    @testset "Stopping Propagation" begin
        spapp = Framework([EmptyPlugin{1}, PropagationStopperPlugin, EmptyPlugin{2}, PropagationCheckerPlugin])
        hooklist(spapp.plugins, propagationtest)(spapp, 42) === true # It is stopped so the checker does not throw
        hooklist(spapp.plugins, propagationtest)(spapp, 32) === false # Not stopped but accepted by the checker
        @test_throws String hooklist(spapp.plugins, propagationtest)(spapp, 41)

        @test hooklist(spapp.plugins, propagationtest_nodata)(spapp) === true
    end

    @testset "HookList iteration" begin
        iapp = Framework([EmptyPlugin{1}, CounterPlugin{2}, EmptyPlugin{2}, CounterPlugin{1}, EmptyPlugin{3}])
        c1 = iapp.plugins[4]
        c2 = iapp.plugins[2]
        hookers = [c2, c1]
        @test length(hooklist(iapp.plugins, hook1)) === 2
        i = 1
        for hook in hooklist(iapp.plugins, hook1)
            @test hookers[i] === hook.plugin
            i += 1
        end
    end

    @testset "Accessing plugins directly" begin
        app = Framework([EmptyPlugin{1}, CounterPlugin{1}])
        empty = app.plugins[1]
        counter = app.plugins[2]
        @test get(app.plugins, :empty) === empty
        @test get(app.plugins, :counter) === counter
        @test app.plugins[:empty] === empty
        @test length(app.plugins) == 2
    end

    @testset "Hook cache" begin
        counters = [CounterPlugin{i} for i=2:40]
        empties = [EmptyPlugin{i} for i=1:100]
        pluginarr = [CounterPlugin{1}, empties..., counters...]
        @info "Measuring time to first hook call with $(length(pluginarr)) uniquely typed plugins, $(length(counters) + 1) implementig the hook."
        @time begin
            simpleapp = SharedState(PluginStack(pluginarr, [hook1]), 0)
            simpleapp_hooks = hooks(simpleapp)
            simpleapp_hooks.hook1(simpleapp)
            @test simpleapp.plugins[1].hook1count == 1
        end
    end

    @testset "Hook cache as type parameter" begin
        counters = [CounterPlugin{i} for i=2:2]
        empties = [EmptyPlugin{i} for i=1:100]
        app = App([CounterPlugin{1}, empties..., counters...], [hook3])
        op(app)
    end

    @testset "Lifecycle Hooks" begin
        app = Framework([EmptyPlugin{1}, LifeCycleTestPlugin])
        plugin = app.plugins[2]
        @test setup!(app.plugins, app).allok == true
        @test plugin.setupcalledwith === app

        # Create a non-standard lifecycle hook
        lifecycle_hook = Plugins.create_lifecyclehook(deferred_init)
        @test string(lifecycle_hook) == "deferred_init"
        @test lifecycle_hook(app.plugins, "42").allok === true
        @test plugin.deferredinitcalledwith === "42"

        @test Plugins.shutdown!(app.plugins, app).allok === true
        @test plugin.shutdowncalledwith === app
        notallok = Plugins.shutdown!(app.plugins, 42)
        @test notallok.allok === false
        @test (notallok.results[2] isa Tuple) === true
        @test (notallok.results[2][1] isa Exception) === true
        @test (stacktrace(notallok.results[2][2]) isa AbstractVector{StackTraces.StackFrame}) === true
        @test plugin.shutdowncalledwith === 42
    end

    @testset "Modifying plugins" begin
        c2 = CounterPlugin{2}()
        app = Framework([EmptyPlugin, CounterPlugin{1}], [hook1])
        c1 = app.plugins[2]
        cache = hooks(app)
        cache.hook1(app)
        push!(app.plugins, c2)
        cache = hooks(app)
        cache.hook1(app)
        @test c2.hook1count == 1
        @test c1.hook1count == 2

        @test pop!(app.plugins) === c2
        cache = hooks(app)
        cache.hook1(app)
        @test c2.hook1count == 1
        @test c1.hook1count == 3

        @test popfirst!(app.plugins) isa EmptyPlugin
        cache = hooks(app)
        cache.hook1(app)
        @test c2.hook1count == 1
        @test c1.hook1count == 4


        pushfirst!(app.plugins, c2)
        cache = hooks(app)
        cache.hook1(app)
        @test c2.hook1count == 2
        @test c1.hook1count == 5
        @test app.plugins[1] === c2

        pop!(app.plugins)
        @test length(app.plugins) == 1
        @test isempty(app.plugins) == false
        pop!(app.plugins)
        @test length(app.plugins) == 0
        @test isempty(app.plugins) == true
        @test_throws ArgumentError pop!(app.plugins)

        app = Framework([EmptyPlugin{1}, CounterPlugin{3}], [hook1])
        c3 = app.plugins[:counter]
        @test isempty(app.plugins) == false
        cache = hooks(app)
        cache.hook1(app)
        @test c3.hook1count == 1
        empty!(app.plugins)
        @test isempty(app.plugins) == true
        cache = hooks(app)
        cache.hook1(app)
        @test c3.hook1count == 1

        c5 = CounterPlugin{5}()
        app = Framework([EmptyPlugin{1}, CounterPlugin{4}], [hook1])
        c4 = app.plugins[:counter]
        @test isempty(app.plugins) == false
        cache = hooks(app)
        cache.hook1(app)
        @test c4.hook1count == 1
        @test c5.hook1count == 0
        app.plugins[2] = c5
        cache = hooks(app)
        cache.hook1(app)
        @test c4.hook1count == 1
        @test c5.hook1count == 1
    end
end
