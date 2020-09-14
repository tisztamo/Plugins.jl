using Plugins
import Plugins
using Test

abstract type AbstractState1 end
abstract type AbstractState2 end

struct Fielder1 <: Plugin end
struct Fielder2 <: Plugin end

Plugins.customfield(plugin::Fielder1, ::Type{AbstractState1}) = Plugins.fieldspec("field1_1", Int64)
Plugins.customfield(plugin::Fielder1, ::Type{AbstractState2}) = Plugins.fieldspec("field1_2", Any)
Plugins.customfield(plugin::Fielder2, ::Type{AbstractState1}) = Plugins.fieldspec(:field2_1, Dict{String, Any})
Plugins.customfield(plugin::Fielder2, ::Type{AbstractState2}) = Plugins.fieldspec(:field2_2, Fielder2)

abstract type AppState end
Plugins.customfield(plugin::Fielder1, ::Type{AppState}) = Plugins.fieldspec("field1", Int64)
Plugins.customfield(plugin::Fielder2, ::Type{AppState}) = Plugins.fieldspec("field2", Float64)

struct CustomFieldsApp{TCustomState}
    state::TCustomState
    function CustomFieldsApp(plugins, hookfns, stateargs...)
        stack = PluginStack(plugins, hookfns)
        state_type = custom_type(stack, :AppStateImpl, AppState)
        return new{state_type}(Base.invokelatest(state_type, stateargs...))
    end
end

@testset "Plugins.jl custom fields" begin
    stack = PluginStack([Fielder1(), Fielder2()])
    res1 = Plugins.customfield(stack, AbstractState1)
    @test res1.allok == true
    @test res1.results[1] == :(field1_1::Int64)
    @test res1.results[2] == :(field2_1::Dict{String, Any})
    res2 = Plugins.customfield(stack, AbstractState2)
    @test res2.allok == true
    @test res2.results[1] == :(field1_2::Any)
    @test res2.results[2] == :(field2_2::Fielder2)

    s1 = custom_type(stack, :State1, AbstractState1)
    @test s1 === State1
    s1i = State1(42, Dict())
    @test s1i.field1_1 == 42
    @test s1i.field2_1 isa Dict

    s2 = custom_type(stack, :State2, AbstractState2)
    @test s2 === State2
    s2i = State2(42, Fielder2())
    @test s2i.field1_2 == 42
    @test s2i.field2_2 isa Fielder2

    app = CustomFieldsApp([Fielder1(), Fielder2()], [], 42, 42.0)
    @test app.state.field1 === 42
    @test app.state.field2 === 42.0
    app.state.field1 = 43
    @test app.state.field1 === 43
    @test_throws Exception app.state.field1 = "43"
end