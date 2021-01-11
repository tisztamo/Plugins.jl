abstract type Interface1 end
struct Impl1 <: Interface1 end

abstract type SubInterface1 <: Interface1 end
struct SubImpl1 <: SubInterface1 end

abstract type SubSubInterface1 <: SubInterface1 end
struct SubSubImpl1 <: SubSubInterface1 end

abstract type SubInterface2 <: Interface1 end
struct SubImpl2 <: SubInterface2 end

@testset "deps: instantiating a single plugin" begin
    @test_throws Any Plugins.instantiation_order([Interface1])
    @test_throws Any Plugins.instantiation_order([SubInterface2])
    Plugins.register(Impl1)
    @test Plugins.instantiation_order([Interface1]) == [Impl1]
    @test_throws Any Plugins.instantiation_order([SubInterface2])
    Plugins.register(SubImpl1)
    @test Plugins.instantiation_order([Interface1]) == [SubImpl1]
    @test Plugins.instantiation_order([SubInterface1]) == [SubImpl1]
    @test_throws Any Plugins.instantiation_order([SubInterface2])
    Plugins.register(SubImpl2)
    @test Plugins.instantiation_order([Interface1])[1] <: Interface1
    @test Plugins.instantiation_order([SubInterface1]) == [SubImpl1]
    @test Plugins.instantiation_order([SubInterface2]) == [SubImpl2]
    Plugins.register(SubSubImpl1)
    @test Plugins.instantiation_order([Interface1])[1] <: Interface1
    @test Plugins.instantiation_order([SubInterface1]) == [SubSubImpl1]
    @test Plugins.instantiation_order([SubSubInterface1]) == [SubSubImpl1]
    @test Plugins.instantiation_order([SubInterface2]) == [SubImpl2]
end

Base.isless(a::Type, b::Type) = isless(nameof(a), nameof(b))

abstract type MI1 end
struct MImpl1 <: MI1 end

abstract type MI2 end
struct MImpl2 <: MI2 end

abstract type MI3 end
struct MImpl3 <: MI3 end

abstract type MI4 end
struct MImpl4 <: MI4 end

abstract type MI5 end
struct MImpl5 <: MI5 end

#using BenchmarkTools

@testset "deps: Multiple plugins" begin
    Plugins.register(MImpl1)
    Plugins.register(MImpl2, [MImpl1])
    Plugins.register(MImpl3, [MI2])
    Plugins.register(MImpl4, [MI1, MI2])
    Plugins.register(MImpl5, [MImpl4, MI2])
    @test sort(Plugins.instantiation_order([MI1, MI2])) == sort([MImpl1, MImpl2])
    @test sort(Plugins.instantiation_order([MI1, MI3])) == sort([MImpl1, MImpl2, MImpl3])
    @test sort(Plugins.instantiation_order([MImpl3, MImpl1])) == sort([MImpl1, MImpl2, MImpl3])
    @test sort(Plugins.instantiation_order([MI1, MI2, MI3, MI4, MI5])) == sort([MImpl1, MImpl2, MImpl3, MImpl4, MImpl5])
    @test sort(Plugins.instantiation_order([MI5, MI4])) == sort([MImpl5, MImpl4, MImpl2, MImpl1])
    @test sort(Plugins.instantiation_order([MI5, MI3])) == sort([MImpl5, MImpl4, MImpl3, MImpl2, MImpl1])
end