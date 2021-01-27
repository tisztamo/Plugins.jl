"""
RootInterface is the root of an interface hierarchy.
Interfaces are modelled with abstract types.
"""
abstract type RootInterface end

"""
Implementation is marked with subtyping the interface
"""
struct RootImpl <: RootInterface end

"""
Interfaces have single inheritance with subtype semantics:
An implementation of a subinterface must also implement
the superinterface.
"""
abstract type SubInterfaceLeft <: RootInterface end
struct SubImplLeft <: SubInterfaceLeft end

abstract type SubInterfaceRight <: RootInterface end
struct SubImplRight <: SubInterfaceRight end

abstract type SubSubInterfaceLeft <: SubInterfaceLeft end
struct SubSubImplLeft <: SubSubInterfaceLeft end

@testset "Finding implementations for single interfaces" begin
    # Throws an error when the required interface or any of its dependencies
    # is unimplemented
    @test_throws Any Plugins.instantiation_order([RootInterface])
    @test_throws Any Plugins.instantiation_order([SubInterface2])

    # Registration is programmatic for now
    Plugins.register(RootImpl)

    # Finds the trivial implementation
    @test Plugins.instantiation_order([RootInterface]) == [RootImpl]
    @test_throws Any Plugins.instantiation_order([SubInterface2])

    # Finds the most specific implementation if multiple are available
    Plugins.register(SubImplLeft)
    @test Plugins.instantiation_order([RootInterface]) == [SubImplLeft]
    @test Plugins.instantiation_order([SubInterfaceLeft]) == [SubImplLeft]
    @test_throws Any Plugins.instantiation_order([SubInterface2])

    # If there are multiple most specific implementations, selects one undefinedly
    Plugins.register(SubImplRight)
    @test Plugins.instantiation_order([RootInterface])[1] <: RootInterface
    
    # Still works
    @test Plugins.instantiation_order([SubInterfaceLeft]) == [SubImplLeft]
    @test Plugins.instantiation_order([SubInterfaceRight]) == [SubImplRight]

    # A two-level hierarchy also works as expected
    Plugins.register(SubSubImplLeft)
    @test Plugins.instantiation_order([RootInterface])[1] <: RootInterface
    @test Plugins.instantiation_order([SubInterfaceLeft]) == [SubSubImplLeft]
    @test Plugins.instantiation_order([SubSubInterfaceLeft]) == [SubSubImplLeft]
    @test Plugins.instantiation_order([SubInterfaceRight]) == [SubImplRight]
end

# ------------------------------------------------------------------------------------------

# Helper for checking permutation equivalence of type arrays
Base.isless(a::Type, b::Type) = isless(nameof(a), nameof(b))

"""
A more realistic example is a small module structure with complex dependencies.
Instantiated implementations receive instances of their dependencies as arguments
to the constructor, and may also receive options through kwargs.
"""
abstract type MI1 <: Plugin  end
struct MImpl1 <: MI1
    x1
    x2
    MImpl1(; x1=nothing, x2=nothing, options...) = new(x1, x2)
end

abstract type MI2 <: Plugin  end
struct MImpl2 <: MI2
    MImpl2(::MI1; options...) = new()
end
Plugins.deps(::Type{MImpl2}) = [MImpl1]

abstract type MI3 <: Plugin  end
struct MImpl3 <: MI3
    MImpl3(::MI1; options...) = new()
end

abstract type MI4 <: Plugin  end
struct MImpl4 <: MI4
    MImpl4(::MI1, ::MI2; options...) = new()
end

abstract type MI5 <: Plugin end
struct MImpl5 <: MI5
    MImpl5(::MI4, ::MI2; options...) = new()
end
Plugins.deps(::Type{MImpl5}) = [MImpl4, MI2]

@testset "Dependency hierarchies are tracked" begin
    Plugins.register(MImpl1)
    Plugins.register(MImpl2)
    Plugins.register(MImpl3, [MI2])
    Plugins.register(MImpl4, [MI1, MI2])
    Plugins.autoregister() # MImpl5
    @test sort(Plugins.instantiation_order([MI1, MI2])) == sort([MImpl1, MImpl2])
    @test sort(Plugins.instantiation_order([MI1, MI3])) == sort([MImpl1, MImpl2, MImpl3])
    @test sort(Plugins.instantiation_order([MImpl3, MImpl1])) == sort([MImpl1, MImpl2, MImpl3])
    @test sort(Plugins.instantiation_order([MI1, MI2, MI3, MI4, MI5])) == sort([MImpl1, MImpl2, MImpl3, MImpl4, MImpl5])
    @test sort(Plugins.instantiation_order([MI5, MI4])) == sort([MImpl5, MImpl4, MImpl2, MImpl1])
    @test sort(Plugins.instantiation_order([MI5, MI3])) == sort([MImpl5, MImpl4, MImpl3, MImpl2, MImpl1])
end

@testset "Instantiation" begin
    @show mi1 = Plugins.instantiate([MI1]; x1=42, x2=43)
    @test length(mi1) == 1
    @test mi1[1] isa MImpl1
    @test mi1[1].x1 == 42
    @test mi1[1].x2 == 43

    @show mi2 = Plugins.instantiate([MI1, MI2]; x1=42, plugins_tests_extraop=:plugins_tests_extraop)
    @test length(mi2) == 2
    @test mi2[1] isa MImpl1
    @test mi2[2] isa MImpl2

    @show mi3 = Plugins.instantiate([MI1, MI4])
    @test length(mi3) == 3
    @test mi3[1] isa MImpl1
    @test mi3[2] isa MImpl4
    @test mi3[3] isa MImpl2

    @show mi4 = Plugins.instantiate([MI1, MI4, MI5])
    @test length(mi4) == 4
    @test mi4[1] isa MImpl1
    @test mi4[2] isa MImpl4
    @test mi4[3] isa MImpl5
    @test mi4[4] isa MImpl2

end