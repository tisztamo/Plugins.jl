"""
    abstract type Stage end

Base type that represents a step of iterated staging.

Iterated staging allows the program to repeatedly self-recompile its parts.
The first iterations are

`Stage` is the root of a layered type hierarchy:

- Direct subtypes of it (ContextStage, EvalStage) represent staging
techniques available in Julia.
- Downstream subtypes represent means of staging:
Initialization, Extension, Optimization, Configuration.
"""
abstract type Stage end

"""
    abstract type ContextStage <: Stage end

Stage technique that generates a new stage context type, which can be used
for dispatching or in `@generated` functions.
Assembled types may be regenerated during a `ContextStage`, depending on TODO.
    
A context stage does not create a new world but run in
the same world than the previous stage.
"""
abstract type ContextStage <: Stage end

"""
    abstract type EvalStage <: Stage end

Stage technique that runs in a new world and generates a new stage context type.
"""
abstract type EvalStage <: Stage end

"""
    abstract type Optimization <: ContextStage end

Stage that does not change the functional behavior of the program,
only its performance characteristics.
"""
abstract type Optimization <: ContextStage end

"""
    abstract type Configuration <: ContextStage end

Stage that potentially changes the behavior of the program
without evaluating previously unknown code.
"""
abstract type Configuration <: ContextStage end

"""
    abstract type Initialization <: EvalStage end

A classical Stage that runs before the normal operation of the program.

Multiple initialization stages may run, but only before the first
non-Initialization stage.
"""
abstract type Initialization <: EvalStage end

"""
    abstract type Extension <: EvalStage end

Stage that evaluates previously unknown code, e.g. loads
new plugins.
"""
abstract type Extension <: EvalStage end
