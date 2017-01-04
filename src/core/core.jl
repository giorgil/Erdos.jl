"""
    vertices(g)

Returns an iterator to the vertices of a graph (i.e. 1:nv(g))
"""
vertices(g::ASimpleGraph) = 1:nv(g)

"""
    adjlist(g)

Returns the adjacency list of a graph (a vector of vector of ints).
It is equivalent to  [`out_adjlist(g)`](@ref).

NOTE: For most graph types it returns a reference, not a copy,
therefore the returned object should not be modified.
"""
adjlist(g::ASimpleGraph) = out_adjlist(g)
in_adjlist(g::AGraph) = out_adjlist(g)

"""
    add_vertices!(g, n)

Add `n` new vertices to the graph `g`. Returns the final number
of vertices.
"""
function add_vertices!(g::ASimpleGraph, n)
    added = true
    for i = 1:n
        add_vertex!(g)
    end
    return nv(g)
end

"""
    has_vertex(g, v)

Return true if `v` is a vertex of `g`.
"""
has_vertex(g::ASimpleGraph, v) = v in vertices(g)

function show{G<:ASimpleGraph}(io::IO, g::G)
    print(io, split("$G",'.')[end],
        "($(nv(g)), $(ne(g)))")
        # is_directed(g) ? " undirected graph" : " directed graph")
end


"""
    is_directed(g)

Check if `g` a graph with directed edges.
"""
is_directed(g::AGraph) = false
is_directed(g::ADiGraph) = true
is_directed{G<:AGraph}(::Type{G}) = false
is_directed{G<:ADiGraph}(::Type{G}) = true

"""
    in_degree(g, v)

Returns the number of edges which start at vertex `v`.
"""
in_degree(g::ASimpleGraph, v) = length(in_neighbors(g,v))

"""
    out_degree(g, v)

Returns the number of edges which end at vertex `v`.
"""
out_degree(g::ASimpleGraph, v) = length(out_neighbors(g,v))

"""
    degree(g, v)

Return the number of edges  from the vertex `v`.
"""
degree(g::ASimpleGraph, v) = out_degree(g, v)

in_degree(g::ASimpleGraph, v::AbstractVector{Int} = vertices(g)) = [in_degree(g,x) for x in v]
out_degree(g::ASimpleGraph, v::AbstractVector{Int} = vertices(g)) = [out_degree(g,x) for x in v]
degree(g::ASimpleGraph, v::AbstractVector{Int} = vertices(g)) = [degree(g,x) for x in v]

"""
    neighbors(g, v)

Returns a list of all neighbors from vertex `v` in `g`.

For directed graph, this is equivalent to [`out_neighbors`](@ref)(g, v).

NOTE: it may return a reference, not a copy. Do not modify result.
"""
neighbors(g::ASimpleGraph, v) = out_neighbors(g, v)
in_neighbors(g::AGraph, v) = out_neighbors(g, v)

"""
    all_neighbors(g, v)

Iterates over all distinct in/out neighbors of vertex `v` in `g`.
"""
all_neighbors(g::AGraph, v) = out_neighbors(g, v)

all_neighbors(g::ADiGraph, v) =
    distinct(chain(out_neighbors(g, v), in_neighbors(g, v)))

"""
    density(g)

Density is defined as the ratio of the number of actual edges to the
number of possible edges. This is ``|v| |v-1|`` for directed graphs and
``(|v| |v-1|) / 2`` for undirected graphs.
"""
density(g::AGraph) = (2*ne(g)) / (nv(g) * (nv(g)-1))
density(g::ADiGraph) = ne(g) / (nv(g) * (nv(g)-1))

"""
    clean_vertex!(g, v)

Remove all incident edges on vertex `v` in `g`.
"""
function clean_vertex!(g::ASimpleGraph, v)
    edgs = collect(all_edges(g, v))
    for e in edgs
        rem_edge!(g, e)
    end
end

copy(g::ASimpleGraph) = deepcopy(g)

graphtype{G<:AGraph}(g::G) = G
digraphtype{G<:ADiGraph}(g::G) = G

graph(g::AGraph) = g
digraph(g::ADiGraph) = g

#### FALLBACKS #################


function digraph(g::AGraph)
    G = digraphtype(g)
    h = G(nv(g))
    for e in edges(g)
        add_edge!(h, src(e), dst(e))
        add_edge!(h, dst(e), src(e))
    end
    return h
end

function graph(g::ADiGraph)
    G = graphtype(g)
    h = G(nv(g))
    for e in edges(g)
        add_edge!(h, src(e), dst(e))
    end
    return h
end

function =={G<:ASimpleGraph}(g::G, h::G)
    nv(g) != nv(h) && return false
    ne(g) != ne(h) && return false
    for i=1:nv(g)
        if sort(collect(out_neighbors(g, i))) != sort(collect(out_neighbors(h, i)))
            return false
        end
    end
    return true
end


"""
    in_adjlist(g)

Returns the backward adjacency list of a graph.
For each vertex the vector of neighbors though incoming edges.

    in_adjlist(g) == [collect(in_neighbors(i)) for i=1:nv(g)]

It is the same as [`adjlist`](@ref) and [`out_adjlist`](@ref) for
undirected graphs.


NOTE: returns a reference, not a copy. Do not modify result.
"""
in_adjlist(g::ADiGraph) = Vector{Int}[collect(in_neighbors(g, i)) for i=1:nv(g)]

"""
    out_adjlist(g)

Returns the forward adjacency list of a graph, i.e. a vector of vectors
containing for each vertex the neighbors trhough outgoing edges.

    out_adjlist(g) == [collect(out_neighbors(i)) for i=1:nv(g)]

The adjacency list is be pre-calculated for most graph types.
It is the same as [`adjlist`](@ref) and [`in_adjlist`](@ref) for
undirected graphs and the same as [`adjlist`](@ref) for directed ones.

NOTE: It may return a reference, not a copy. Do not modify result.

"""
out_adjlist(g::ASimpleGraph) = Vector{Int}[collect(out_neighbors(g, i)) for i=1:nv(g)]


"""
    has_edge(g, e)
    has_edge(g, u, v)

Returns true if the graph `g` has an edge `e` (from `u` to `v`).
"""
function has_edge(g::AGraph, u, v)
    u > nv(g) || v > nv(g) && return false
    if degree(g, u) > degree(g, v)
        u, v = v, u
    end
    return v ∈ neighbors(g, u)
end

function has_edge(g::ADiGraph, u, v)
    (u > nv(g) || v > nv(g)) && return false
    if out_degree(g, u) < in_degree(g, v)
        return v ∈ out_neighbors(g, u)
    else
        return u ∈ in_neighbors(g, v)
    end
end

"""
    in_edges(g, v)

Returns an iterator to the edges in `g` going to vertex `v`.
`v == dst(e)` for each returned edge `e`.
"""
in_edges(g::ASimpleGraph, v) = (edge(g, x, v) for x in in_neighbors(g, v))

"""
    out_edges(g, v)

Returns an iterator to the edges in `g` coming from vertex `v`.
`v == src(e)` for each returned edge `e`.
"""
out_edges(g::ASimpleGraph, v) = (edge(g, v, x) for x in out_neighbors(g, v))

"""
    edges(g, v)

Returns an iterator to the edges in `g` coming from vertex `v`.
`v == src(e)` for each returned edge `e`.

It is equivalent to [`out_edges`](@ref).

For digraphs, use [`all_edges`](@ref) to iterate over
both in and out edges.
"""
edges(g::ASimpleGraph, v) = out_edges(g, v)

"""
    all_edges(g, v)

Iterates over all in and out edges of vertex `v` in `g`.
"""
all_edges(g::AGraph, v) = out_edges(g, v)
all_edges(g::ADiGraph, v) = chain(out_edges(g, v), in_edges(g, v))
#TODO fix chain eltype, since collect gives Any[...]

"""
    reverse(g::ADiGraph)

Produces a graph where all edges are reversed from the
original.
"""
function reverse{G<:ADiGraph}(g::G)
    h = G(nv(g))
    for e in edges(g)
        add_edge!(h, reverse(e))
    end
    return h
end

"""
    reverse!(g::DiGraph)

In-place reverse (modifies the original graph).
"""
reverse!(g::ADiGraph) = nothing

add_edge!(g::ASimpleGraph, e::AEdge) = add_edge!(g, src(e), dst(e))
rem_edge!(g::ASimpleGraph, e::AEdge) = rem_edge!(g, src(e), dst(e))
has_edge(g::ASimpleGraph, e::AEdge) = has_edge(g, src(e), dst(e))
