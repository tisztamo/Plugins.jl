# Plugins

### An extension system for Julia 

[![CI](https://github.com/tisztamo/Plugins.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/tisztamo/Plugins.jl/actions/workflows/ci.yml)
[![Codecov](https://codecov.io/gh/tisztamo/Plugins.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/tisztamo/Plugins.jl)
![experimental](https://img.shields.io/badge/lifecycle-experimental-blue.svg)

[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://tisztamo.github.io/Plugins.jl/dev)


# Introduction

A plugin (aka extension) is a chunk of code that extends the functionality of a system. It implements so-called hooks to react to events generated by the system.

The plugin-based architecture is a popular way to develop maintainable and extensible software, but its dynamic nature introduces a performance penalty that is not always acceptable. You tipically cannot hook into performance-critical points.

Plugins.jl helps by analyzing the plugins loaded into the system and generating efficient, statically dispatched event handling code, thus allowing full optimization.

With Plugins.jl, execution of plugin code can be just as performant as a manually composed system. *Inlinable hook implementations will be merged into a single function body, and non-implementing plugins are skipped with zero overhead.*

Interested? Please find more info in the [documentation](https://tisztamo.github.io/Plugins.jl/dev)!
