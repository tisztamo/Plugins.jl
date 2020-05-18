using Plugins
using Test

struct Framework{TPlugin}
    firstplugin::TPlugin
end

struct EmptyPlugin{Next} <: Plugin
    next::Next
    EmptyPlugin(next::Next) where Next = new{Next}(next)
end

mutable struct CounterPlugin{Next} <: Plugin
    next::Next
    hook1count::Int
    hook2count::Int
    CounterPlugin(next::Next) where Next = new{Next}(next, 0, 0)
end
@inline hook1_handler(plugin::CounterPlugin{Next}, framework) where Next = plugin.hook1count += 1
@inline hook2_handler(plugin::CounterPlugin{Next}, framework) where Next = plugin.hook2count += 1

function chain_of_empties(terminal, length=10)
    inner = terminal
    for i = 1:length
        inner = EmptyPlugin(inner)
    end
    return inner
end

mutable struct FrameworkTestPlugin{Next} <: Plugin
    next::Next
    calledwithframework
    FrameworkTestPlugin(next) = new{typeof(next)}(next, "Never called")
end
hook1_handler(plugin::FrameworkTestPlugin{Next}, framework) where Next = plugin.calledwithframework = framework

@testset "Plugins.jl" begin
    @testset "Plugin chain" begin
        innerplugins = EmptyPlugin(TerminalPlugin())
        counter = CounterPlugin(innerplugins)
        a1 = Framework(counter)
        a1_hook1s = hooks(a1, hook1_handler)
        for i=1:1e5 a1_hook1s() end
        @time for i=1:1e5 a1_hook1s() end
        hooks(a1, hook2_handler)()
        @test counter.hook1count == 2e5
        @test counter.hook2count == 1
    end

    @testset "Same plugin twice" begin
        innercounter = CounterPlugin(TerminalPlugin())
        outercounter = CounterPlugin(innercounter)
        @show a2 = Framework(outercounter)
        @show a2_hook1s = hooks(a2, hook1_handler)
        for i=1:1e5 a2_hook1s() end
        @time for i=1:1e5 a2_hook1s() end
        hooks(a2, hook2_handler)()
        @test innercounter.hook1count == 2e5
        @test innercounter.hook2count == 1
        @test outercounter.hook1count == 2e5
        @test outercounter.hook2count == 1
    end

    @testset "Chain of empty Plugins to eliminate" begin
        innerchainedplugin = CounterPlugin(chain_of_empties(TerminalPlugin()))
        chainedplugin = CounterPlugin(chain_of_empties(innerchainedplugin))
        chainedapp = Framework(chainedplugin)

        chainedapp_hook1s = hooks(chainedapp, hook1_handler)
        for i=1:1e5 chainedapp_hook1s() end
        @time for i=1:1e5 chainedapp_hook1s() end
        @test chainedplugin.hook1count == 2e5
        @test chainedplugin.hook2count == 0
        @test innerchainedplugin.hook1count == 2e5
        @test innerchainedplugin.hook2count == 0
    end

    @testset "Framework goes through" begin
        frameworktestapp = Framework(FrameworkTestPlugin(TerminalPlugin()))
        hooks(frameworktestapp, hook1_handler)()
        @test frameworktestapp.firstplugin.calledwithframework === frameworktestapp
    end
end
