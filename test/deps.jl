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
struct MImpl1 <: MI1
    x1
    x2
    MImpl1(; x1=nothing, x2=nothing) = new(x1, x2)
end

abstract type MI2 end
struct MImpl2 <: MI2
    MImpl2(::MI1) = new()
end

abstract type MI3 end
struct MImpl3 <: MI3 end

abstract type MI4 end
struct MImpl4 <: MI4
    MImpl4(::MI1, ::MI2) = new()
end

abstract type MI5 end
struct MImpl5 <: MI5
    MImpl5(::MI4, ::MI2) = new()
end

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

@testset "Instantiation" begin
    mi1 = Plugins.instantiate([MI1]; x1=42, x2=43)
    @test length(mi1) == 1
    @test mi1[1] isa MImpl1
    @test mi1[1].x1 == 42
    @test mi1[1].x2 == 43

    mi2 = Plugins.instantiate([MI1, MI2])
    @test length(mi2) == 2
    @test mi2[1] isa MImpl1
    @test mi2[2] isa MImpl2

    mi3 = Plugins.instantiate([MI1, MI4])
    @test length(mi3) == 3
    @test mi3[1] isa MImpl1
    @test mi3[2] isa MImpl2
    @test mi3[3] isa MImpl4

    mi4 = Plugins.instantiate([MI1, MI4, MI5])
    @test length(mi4) == 4
    @test mi4[1] isa MImpl1
    @test mi4[2] isa MImpl2
    @test mi4[3] isa MImpl4
    @test mi4[4] isa MImpl5

end