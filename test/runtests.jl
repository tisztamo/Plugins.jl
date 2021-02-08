using Plugins
import Plugins.symbol, Plugins.setup!, Plugins.setup!
using Test
using Random

# To run only selected tests, use e.g.:
#
#   Pkg.test("Plugins", test_args=["deps"])
#
enabled_tests = lowercase.(ARGS)
function addtests(fname)
    key = lowercase(splitext(fname)[1])
    if isempty(enabled_tests) || key in enabled_tests
        Random.seed!(42)
        include(fname)
    end
end

addtests("basics.jl")
addtests("deps.jl")
addtests("assembled_types.jl")
