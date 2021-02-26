using Plugins
import Plugins
using Test

abstract type AbstractState1 end
Plugins.TemplateStyle(::Type{AbstractState1}) = Plugins.ImmutableStruct()
abstract type AbstractState2 end
abstract type AbstractState3 end

struct Fielder1 <: Plugin end
Plugins.register(Fielder1)
struct Fielder2 <: Plugin end
Plugins.register(Fielder2)

_numberinit() =  0
_numberinit(p) = p
_any() = nothing
_dict() = Dict()
_dict(p) = Dict(string(p) => p)

Plugins.customfield(plugin::Fielder1, ::Type{AbstractState1}) = Plugins.FieldSpec("field1_1", Int64, _numberinit)
Plugins.customfield(plugin::Fielder1, ::Type{AbstractState2}) = Plugins.FieldSpec("field1_2", Any, _any)
Plugins.customfield(plugin::Fielder2, ::Type{AbstractState1}) = Plugins.FieldSpec(:field2_1, Dict{String, Any}, _dict)
Plugins.customfield(plugin::Fielder2, ::Type{AbstractState2}) = Plugins.FieldSpec(:field2_2, Fielder2)

Plugins.customfield(plugin::Fielder2, ::Type{AbstractState3}) = Plugins.FieldSpec(:field2_2, "this_should_throw")

abstract type AppState end

struct CustomTemplate <: Plugins.TemplateStyle end
Plugins.TemplateStyle(::Type{AppState}) = CustomTemplate()

Plugins.typedef(::CustomTemplate, spec) = quote
    evaltest = true
    mutable struct TYPE_NAME <: $(spec.parent_type)
        $(Plugins.structfields(spec))
    end;
    $(Plugins.default_constructor(spec))
    TYPE_NAME
end

Plugins.customfield(plugin::Fielder1, ::Type{AppState}) = Plugins.FieldSpec("field1", Int64, _numberinit)
Plugins.customfield(plugin::Fielder2, ::Type{AppState}) = Plugins.FieldSpec("field2", Float64, _numberinit)

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

Plugins.typedef(::ErrTemplate, spec) = quote
    evaltest = true
    dfgdfg
    TYPE_NAME
end

@testset "Plugins.jl custom fields" begin
    @test isnothing(Plugins.customfield(Fielder1(), AbstractArray)) == true

    stack = PluginStack([Fielder1, Fielder2])
    res1 = Plugins.customfields(stack, AbstractState1)
    @test res1.allok == true
    @test res1.results[1] == Plugins.FieldSpec(:field1_1, Int64, _numberinit)
    @test res1.results[2] == Plugins.FieldSpec(:field2_1, Dict{String, Any}, _dict)
    res2 = Plugins.customfields(stack, AbstractState2)
    @test res2.allok == true
    @test res2.results[1] == Plugins.FieldSpec(:field1_2, Any, _any)
    @test res2.results[2] == Plugins.FieldSpec(:field2_2, Fielder2)

    s1 = customtype(stack, :State1, AbstractState1; unique_name=false)
    @test startswith(string(s1), "State1") == true
    s1i = s1(0, Dict())
    @test s1i.field1_1 == 0
    @test_throws Exception s1i.field1_1 = 43
    @test s1i.field2_1 isa Dict

    s1i2 = s1()
    @test s1i2.field1_1 == 0
    @test_throws Exception s1i2.field1_1 = 43
    @test s1i2.field2_1 isa Dict
    @test length(s1i2.field2_1) == 0

    s1i3 = s1(42)
    @test s1i3.field1_1 == 42
    @test_throws Exception s1i3.field1_1 = 43
    @test s1i3.field2_1 isa Dict
    @test length(s1i3.field2_1) == 1
    @test s1i3.field2_1["42"] == 42

    s2 = customtype(stack, :State2, AbstractState2)
    s2i = s2(0, Fielder2())
    @test s2i.field1_2 == 0
    @test s2i.field2_2 isa Fielder2

    s2i2 = s2()
    @test isnothing(s2i2.field1_2)
    @test s2i.field2_2 isa Fielder2

    # Same params yield to same type
    s2_1 = customtype(stack, :State2, AbstractState2)
    @test s2_1 == s2
    @test length(string(s2_1)) > length(string(:State2))
    
    # different params lead to different types
    s2_2 = customtype(stack, :State2, AbstractState1)
    @test s2_2 != s2_1
    @test length(string(s2_2)) > length(string(:State2))

    @test_throws Exception customtype(stack, :State2, AbstractState3)

    app = CustomFieldsApp([Fielder1, Fielder2], [], 0, 0.0)
    @test app.state.field1 === 0
    @test app.state.field2 === 0.0
    app.state.field1 = 43
    @test app.state.field1 === 43
    @test_throws Exception app.state.field1 = "43"
    @test evaltest == true
    testinjected(app, 43, 43.0)
    @test app.state.field1 === 43

    @test s1().field1_1 == 0
    @test s1().field2_1 isa Dict{String, Any}

    errstack = PluginStack([])
    @test_throws Exception customtype(errstack, :ErrState2, ErrState)

    # Parametetric type
    st1 = customtype(stack, :StateT1, AbstractState1, [:T1])
    @test typeof(st1) === UnionAll
    st1i = st1{Int}(0, Dict())
    @test st1i.field1_1 == 0
    @test_throws Exception st1i.field1_1 = 43
    @test st1i.field2_1 isa Dict
end
