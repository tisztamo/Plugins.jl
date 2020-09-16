using Plugins
import Plugins
using Test

abstract type AbstractState1 end
Plugins.TemplateStyle(::Type{AbstractState1}) = Plugins.ImmutableStruct()
abstract type AbstractState2 end
abstract type AbstractState3 end

struct Fielder1 <: Plugin end
struct Fielder2 <: Plugin end

Plugins.customfield(plugin::Fielder1, ::Type{AbstractState1}) = Plugins.FieldSpec("field1_1", Int64)
Plugins.customfield(plugin::Fielder1, ::Type{AbstractState2}) = Plugins.FieldSpec("field1_2", Any)
Plugins.customfield(plugin::Fielder2, ::Type{AbstractState1}) = Plugins.FieldSpec(:field2_1, Dict{String, Any})
Plugins.customfield(plugin::Fielder2, ::Type{AbstractState2}) = Plugins.FieldSpec(:field2_2, Fielder2)

Plugins.customfield(plugin::Fielder2, ::Type{AbstractState3}) = Plugins.FieldSpec(:field2_2, "this_should_throw")

abstract type AppState end

struct CustomTemplate <: Plugins.TemplateStyle end
Plugins.TemplateStyle(::Type{AppState}) = CustomTemplate()

Plugins.typedef(::CustomTemplate, typename, parent_type, fields) = quote
    evaltest = true
    mutable struct $typename <: $parent_type
        $(Plugins.structfields(fields))
    end;
    $typename
end

Plugins.customfield(plugin::Fielder1, ::Type{AppState}) = Plugins.FieldSpec("field1", Int64)
Plugins.customfield(plugin::Fielder2, ::Type{AppState}) = Plugins.FieldSpec("field2", Float64)

mutable struct CustomFieldsApp{TCustomState}
    state::TCustomState
    function CustomFieldsApp(plugins, hookfns, stateargs...)
        stack = PluginStack(plugins, hookfns)
        state_type = customtype(stack, :AppStateImpl, AppState)
        return new{state_type}(Base.invokelatest(state_type, stateargs...))
    end
end

function testinjected(app::CustomFieldsApp{TState}, stateargs...) where TState
    app.state = TState(stateargs...) # No need to invokelatest
end


abstract type ErrState end

struct ErrTemplate <: Plugins.TemplateStyle end
Plugins.TemplateStyle(::Type{ErrState}) = ErrTemplate()

Plugins.typedef(::ErrTemplate, typename, parent_type, fields) = quote
    evaltest = true
    dfgdfg
    mutable struct $typename <: $parent_type
        $(Plugins.structfields(fields))
    end;
    $typename
end

@testset "Plugins.jl custom fields" begin
    @test isnothing(Plugins.customfield(Fielder1(), AbstractArray)) == true

    stack = PluginStack([Fielder1(), Fielder2()])
    res1 = Plugins.customfield(stack, AbstractState1)
    @test res1.allok == true
    @test res1.results[1] == Plugins.FieldSpec(:field1_1, Int64)
    @test res1.results[2] == Plugins.FieldSpec(:field2_1, Dict{String, Any})
    res2 = Plugins.customfield(stack, AbstractState2)
    @test res2.allok == true
    @test res2.results[1] == Plugins.FieldSpec(:field1_2, Any)
    @test res2.results[2] == Plugins.FieldSpec(:field2_2, Fielder2)

    s1 = customtype(stack, :State1, AbstractState1)
    @test s1 === State1
    s1i = State1(42, Dict())
    @test s1i.field1_1 == 42
    @test_throws Exception s1i.field1_1 = 43
    @test s1i.field2_1 isa Dict

    s2 = customtype(stack, :State2, AbstractState2)
    @test s2 === State2
    s2i = State2(42, Fielder2())
    @test s2i.field1_2 == 42
    @test s2i.field2_2 isa Fielder2

    @test_throws Exception customtype(stack, :State2, AbstractState3)

    @show app = CustomFieldsApp([Fielder1(), Fielder2()], [], 42, 42.0)
    @test app.state.field1 === 42
    @test app.state.field2 === 42.0
    app.state.field1 = 43
    @test app.state.field1 === 43
    @test_throws Exception app.state.field1 = "43"
    @test evaltest == true
    testinjected(app, 43, 43.0)
    @test app.state.field1 === 43

    errstack = PluginStack([])
    @test_throws Exception customtype(errstack, :ErrState2, ErrState)
end
