function graphml_read_one_graph!{G}(el::EzXML.Node, ::Type{G})
    nodes = Dict{String,Int}()
    E = Edge{Int}
    edges = Vector{E}()

    nodeid = 1
    for f in eachelement(el)
        if name(f) == "node"
            nodes[f["id"]] = nodeid
            nodeid += 1
        elseif name(f) == "edge"
            n1 = f["source"]
            n2 = f["target"]
            push!(edges, E(nodes[n1], nodes[n2]))
        else
            warn("Skipping unknown node '$(name(f))'")
        end
    end
    g = G(length(nodes))
    for edge in edges
        add_edge!(g, edge)
    end
    return g
end

graphmlparse(T, x::String) = parse(T, x)
graphmlparse(::Type{String}, x::String) = x
if VERSION < v"0.6.0-dev.693" # julia PR #16986
graphmlparse{T}(::Type{Vector{T}}, x::String) =
    map(v->parse(T,v),  split(x, ','))
else
graphmlparse{T}(::Type{Vector{T}}, x::String) = parse.(T, split(x, ','))
end

function graphml_read_one_net!{G}(xg::EzXML.Node, ::Type{G},
                        gpropkeys, vpropkeys, epropkeys)
    nodes = Dict{String,Int}()
    nodeid = 1
    # traverse the tree to map id to 1:n
    for f in eachelement(xg)
        name(f) != "node" && continue
        nodes[f["id"]] = nodeid
        nodeid += 1
    end

    g = G(length(nodes))
    for (pname,T) in values(vpropkeys); vprop!(g, pname, T); end
    for (pname,T) in values(epropkeys); eprop!(g, pname, T); end

    for f in eachelement(xg)
        if name(f) == "node"
            for el in eachelement(f)
                name(el) != "data" && continue
                i = nodes[f["id"]]
                pname, T = vpropkeys[el["key"]]
                m = vprop(g, pname)
                m[i] = graphmlparse(T, content(el))
            end
        elseif name(f) == "edge"
            n1 = f["source"]
            n2 = f["target"]
            ok, e = add_edge!(g, nodes[n1], nodes[n2]) #TODO
            for el in eachelement(f)
                name(el) != "data" && continue
                pname, T = epropkeys[el["key"]]
                m = eprop(g, pname)
                m[e] = graphmlparse(T, content(el))
            end
        elseif name(f) == "data"
            pname, T = gpropkeys[f["key"]]
            gprop!(g, pname, graphmlparse(T, content(f)))
        else
            warn("Skipping unknown xml-node '$(name(f))'")
        end
    end
    return g
end

function readgraphml{G<:AGraphOrDiGraph}(io::IO, ::Type{G})
    xdoc = parsexml(readstring(io))
    xroot = root(xdoc)  # an instance of XMLElement
    name(xroot) == "graphml" || error("Not a GraphML file")
    xg = getchild(xroot, "graph")
    isdir = false
    if haskey(xg, "edgedefault")
        isdir = xg["edgedefault"] == "directed"  ? true  : false
    end
    H = isdir ? digraphtype(G) : graphtype(G)
    return graphml_read_one_graph!(xg, H)
end


function readnetgraphml{G<:AGraphOrDiGraph}(io::IO, ::Type{G})
    xdoc = parsexml(readstring(io))
    xroot = root(xdoc)  # an instance of XMLElement
    name(xroot) == "graphml" || error("Not a GraphML file")
    xg = getchild(xroot, "graph")
    isdir = false
    if haskey(xg, "edgedefault")
        isdir = xg["edgedefault"] == "directed"  ? true  : false
    end

    gpropkeys=Dict{String, Tuple{String, DataType}}();
    vpropkeys=Dict{String, Tuple{String, DataType}}();
    epropkeys=Dict{String, Tuple{String, DataType}}();
    for el in eachelement(xroot)
        name(el) != "key" && continue
        if el["for"] == "graph"
            gpropkeys[el["id"]] = (el["attr.name"], graphml_types_rev[el["attr.type"]])
        elseif el["for"] == "node"
            vpropkeys[el["id"]] = (el["attr.name"], graphml_types_rev[el["attr.type"]])
        elseif el["for"] == "edge"
            epropkeys[el["id"]] = (el["attr.name"], graphml_types_rev[el["attr.type"]])
        end
    end

    H = isdir ? digraphtype(G) : graphtype(G)
    return graphml_read_one_net!(xg, H, gpropkeys, vpropkeys, epropkeys)
end


function writegraphml(io::IO, g::AGraphOrDiGraph)
    xdoc = XMLDocument()
    xroot = setroot!(xdoc, ElementNode("graphml"))
    xroot["xmlns"] = "http://graphml.graphdrawing.org/xmlns"
    xroot["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
    xroot["xsi:schemaLocation"] = "http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd"

    xg = addelement!(xroot, "graph")
    xg["edgedefault"] = is_directed(g) ? "directed" : "undirected"
    for i in 1:nv(g)
        xv = addelement!(xg, "node")
        xv["id"] = "n$(i-1)"
    end
    for e in edges(g)
        xe = addelement!(xg, "edge")
        xe["source"] = "n$(src(e)-1)"
        xe["target"] = "n$(dst(e)-1)"
    end
    prettyprint(io, xdoc)
    return 1
end

const graphml_types = Dict( Int32 => "int",
                            Int64 => "int",
                            Bool => "boolean",
                            Float32 => "double",
                            Float64 => "double",
                            String => "string",
                            Vector{Float32} => "vector_double",
                            Vector{Float64} => "vector_double"
                        )

const graphml_types_rev = Dict("int"  =>  Int,
                            "long"    =>  Int,
                            "boolean" =>  Bool,
                            "float"   =>  Float32,
                            "double"  =>  Float64,
                            "string"  =>  String,
                            "vector_float" => Vector{Float64},
                            "vector_double" => Vector{Float64}
                        )

graphmlstring(x) = string(x)
graphmlstring(v::Vector) = join((@sprintf("%.10g",x) for x in v), ", ")

function writenetgraphml(io::IO, g::ANetOrDiNet)
    xdoc = XMLDocument()
    xroot = setroot!(xdoc, ElementNode("graphml"))
    xroot["xmlns"] = "http://graphml.graphdrawing.org/xmlns"
    xroot["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
    xroot["xsi:schemaLocation"] = "http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd"

    nprop = 0
    gpropkey = Dict{String,String}()
    for (pname, p) in gprop(g)
        xp = addelement!(xroot, "key")
        xp["id"] = "key$nprop"
        gpropkey[pname] = "key$nprop"
        xp["for"] = "graph"
        xp["attr.name"] = pname
        xp["attr.type"] = graphml_types[typeof(p)]
        nprop+=1
    end
    vpropkey = Dict{String,String}()
    for (pname, p) in vprop(g)
        xp = addelement!(xroot, "key")
        xp["id"] = "key$nprop"
        vpropkey[pname] = "key$nprop"
        xp["for"] = "node"
        xp["attr.name"] = pname
        xp["attr.type"] = graphml_types[valtype(p)]
        nprop+=1
    end
    epropkey = Dict{String,String}()
    for (pname, p) in eprop(g)
        xp = addelement!(xroot, "key")
        xp["id"] = "key$nprop"
        epropkey[pname] = "key$nprop"
        xp["for"] = "edge"
        xp["attr.name"] = pname
        xp["attr.type"] = graphml_types[valtype(p)]
        nprop+=1
    end

    xg = addelement!(xroot, "graph")
    xg["edgedefault"] = is_directed(g) ? "directed" : "undirected"
    for (pname, p) in gprop(g)
        xp = addelement!(xg, "data")
        xp["key"] = gpropkey[pname]
        setcontent!(xp, graphmlstring(p))
    end

    for i in 1:nv(g)
        xv = addelement!(xg, "node")
        xv["id"] = "n$(i-1)"
        for (pname,p) in vprop(g)
            xp = addelement!(xv, "data")
            xp["key"] = vpropkey[pname]
            setcontent!(xp, graphmlstring(p[i])) #TODO check has key
        end
    end

    for e in edges(g)
        xe = addelement!(xg, "edge")
        xe["source"] = "n$(src(e)-1)"
        xe["target"] = "n$(dst(e)-1)"
        for (pname, p) in eprop(g)
            xp = addelement!(xe, "data")
            xp["key"] = epropkey[pname]
            setcontent!(xp, graphmlstring(p[e])) #TODO check has key
        end
    end
    prettyprint(io, xdoc)
    return 1
end

filemap[:graphml] = (readgraphml, writegraphml, readnetgraphml, writenetgraphml)
