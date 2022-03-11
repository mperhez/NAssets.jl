"""
Check if vertex has property
"""
function has_prop_vertex(value,g,prop)
    gvs = [ g[v,prop] for v in vertices(g) ]
    return value in gvs
end

"""
Ordering tuples of paths 
1: tick
2: score
"""
function isless_paths(a,b)
    # return @match a,b begin
    #     a[2] < b[2] 
    # end
    if a[2] == b[2]
        return a[1] > b[1]
    else
        return a[2] < b[2]
    end
end

"""
Join two subgraphs assuming they are both part of a global graph.
The id in the global graph is given by property :eid.
"""
function join_subgraphs(g1,g2)
    gt = deepcopy(g1)
    eqv = []
    for v in vertices(g2)
        
        gv = g2[v,:eid]
        
        lv = to_local_vertex(gt,gv)

        if lv == 0
            add_vertex!(gt,:eid,gv)
            push!(eqv,(v,nv(gt)))
        else
            push!(eqv,(lv,gv))
        end
    end

    for e in edges(g2)
        
        

        src_t = to_local_vertex(gt,g2[src(e),:eid])
        dst_t = to_local_vertex(gt,g2[dst(e),:eid])
        add_edge!(gt,src_t,dst_t)

        
        # add_edge!(gt,
        #     first([last(x) for x in eqv if first(x) == src(e) ]),
        #     first([last(x) for x in eqv if first(x) == dst(e) ]),
        # )
    end
    return gt
end

#function (lg, predictions_traffic, predictions_rul)

"""
Search for a path between nodes s and d in the local graph lg
It assumes property :eid of each vertex is global id of vertex
"""

# function query_paths(lg::SimpleWeightedGraph,s,d)
function query_paths(lg,s,d)
    ls = to_local_vertex(lg,s)
    ld = to_local_vertex(lg,d)
    paths = []
    scores = []
    result =   YenState{Float64,Int64}(scores,paths)

    if ls > 0 && ld > 0
            #slg = SimpleGraph(lg)
            #return yen_k_shortest_paths(slg,ls,ld, weights(slg),2,Inf)
            result = yen_k_shortest_paths(lg,ls,ld)
    end
    
    #gvs = [ lg[v,:eid] for v in vertices(lg)]
    #log_info("network contains: gvs: $gvs")
    # log_info("query_path:  g v: $(vertices(lg)), s: $(s) - ls: $(ls), d: $d - ld $ld result ==> $(result)")
    
    
    for path in result.paths
        # path = !isempty(path) && typeof(path) == Array{Array{Int64,1},1} ? first(path) : path
        #convert paths to global graph (eids)
        cpath = [ lg[v,:eid] for v in path]
        push!(paths,cpath)
        push!(scores,score_path(cpath))
    end

    result =   YenState{Float64,Int}(scores,paths)
    
    return result
end

"""
It gives a score to the given path, initially only based on length of path
"""
function score_path(path)
    return length(path)
end

"""
Local search receiving source and destination in a tuple
"""
function query_paths(lg,t)
    query_paths(lg,t...)
end


"""
obtains local id of a vertex given its global id in property :eid
"""
function to_local_vertex(lg,gv)
    lv = [ x for x=1:nv(lg) if lg[x,:eid] == gv]
    return isempty(lv) ? 0 : first(lv)
end

"""
obtains local id of a vertex given its global id in property in gid
"""
function to_local_vertex(lg,gv,gid::Symbol)
    lv = [ x for x=1:nv(lg) if lg[x,gid] == gv]
    return isempty(lv) ? 0 : first(lv)
end

"""
Creates a subgraph (MetaGraph) for the given 
adjacency matrix (m) and vector of equivalences (eqv).
In eqv, every pair has the form: (lv,gv) where lv is the
local vertex id and gv is the global vertex id.
"""
function create_subgraph(m,eqv)
    gw = SimpleWeightedGraph(m)
    g = MetaGraph(m)
    [ set_prop!(g, r, c, :weight, weights(gw)[r,c]) for r=1:size(weights(gw),1),c=1:size(weights(gw),2) if weights(gw)[r,c] >0]

    for eq in eqv
        set_props!(g,first(eq),Dict(:eid=>last(eq)))
    end
    set_indexing_prop!(g, :eid)
    return g
end

"""
Creates a subgraph (MetaGraph) for the given 
edge list and vector of equivalences (eqv).
In eqv, every pair has the form: (lv,gv) where lv is the
local vertex id and gv is the global vertex id.
"""
function create_subgraph(egs,eqv,gid_prop)
    #log_info("Creating subgraph egs: $(egs) and eqv: $eqv")
    g = MetaGraph()
    set_indexing_prop!(g, gid_prop)

    #create vertices
    n_v = max([ src(e) > dst(e) ? src(e) : dst(e) for e in egs]...)

    for v=1:n_v
        gid = last(first([ x for x in eqv if first(x) == v]))
        add_vertex!(g,gid_prop,gid)
    end

    #create edges 

    for e in egs
        add_edge!(g,src(e),dst(e))
        add_edge!(g,dst(e),src(e))
    end

    return g
end

function soft_remove_vertex(g::AbstractGraph,dpn_id::Int)
    
    new_g = deepcopy(g)
    nbs₀ = deepcopy(all_neighbors(new_g,dpn_id))

    for nb in nbs₀
        rem_edge!(new_g,dpn_id,nb)
        rem_edge!(new_g,nb,dpn_id)
    end
    return new_g#
end

function remove_vertex(g::AbstractGraph,dpn_id::Int)
    sm_g = sparse(g)
    sm_new_g = spzeros((nv(g)-1),(nv(g)-1))
    for i=1:nv(g)
        for j=1:nv(g)
            #log_info(" $i,$j value: $(sparse(ntw)[i,j])")
                x,y =   i < dpn_id && j < dpn_id ? (i,j) : 
                        i < dpn_id && j > dpn_id ? (i,j-1) : 
                        i > dpn_id && j < dpn_id ? (i-1,j) : 
                        i > dpn_id && j > dpn_id ? (i-1,j-1) : (0,0)
                
                if x > 0 && y > 0
                    sm_new_g[x,y] = sm_g[i,j]
                    sm_new_g[y,x] = sm_g[j,i]
                end
        end
    end
    #[i >=dpn_id ? labels[i] = i+1 : labels[i] = i  for i in keys(labels)]
    return MetaGraph(sm_new_g)
end

function remove_vertices(g::AbstractGraph,dpn_ids::Array{Int})
    new_g = g
    for dpn_id in dpn_ids
        new_g = remove_vertex!(new_g,dpn_id)
    end
    return new_g
end

"""
Add edges between the local vertex lv and the list of gids (global ids passed) using property gid
"""
function add_edges_gids(g,lv,nbs_gids,gid)
    nb_lvs = []
    for v in vertices(g)
        if g[v,gid] in nbs_gids
            push!(nb_lvs,v)
        end
    end

    for nb in nb_lvs
        add_edge!(g,lv,nb)
    end
    
    return g
end


"""
get_graph

Get underlying graph, passing the adj matrix and separator.
"""
function get_graph(seed,size,topo;k=0,B=0,adj_m_csv=nothing,sep=';')
    Random.seed!(seed)
    ntw = @match topo begin
        GraphModel(0)=> load_graph_from_csv(adj_m_csv;sep=sep)#custom_topo
        GraphModel(2) => MetaGraph( [Int(i) for i in ring_graph(size)])
        GraphModel(3) => MetaGraph(complete_graph(size))
        GraphModel(4) => MetaGraph( [Int(i) for i in grid2(Int(sqrt(size)))])
        GraphModel(5) => MetaGraph( [Int(i) for i in Laplacians.star_graph(size)] )
        GraphModel(6) => MetaGraph(barabasi_albert(size,k,seed=seed))
        GraphModel(7) => MetaGraph(watts_strogatz(size,k,B,seed=seed))
    end
end
"""
It generates subgraph for the vector of nodes passed. This is similar to egonet but it keeps custom indexes given in id_prop parameter.

- g: graph
- It receives vector of controlled assets (nodes)
- id_prop: :eid (simNE) or :aid (agent)
"""
function get_subgraph(g,nodes,id_prop)
    # calculate local subgraph for the underlying network
    
    nbs = []

    for i=1:length(nodes)
        # get vertex for node id (assumes only one)
        v = first(filter(v->get_prop(g,v,id_prop) == nodes[i],1:nv(g)))
        
        #subgraph
        push!(nbs,[ get_prop(g,j,id_prop) for j in neighbors(g,v)])
        #push!(nbs,neighbors(g,nodes[i]))
        push!(nbs,[nodes[i]])
    end
    nnbs = vcat(nbs...)
    sub_g = deepcopy(g)
    vs = [ get_prop(sub_g,v,id_prop) for v in collect(vertices(sub_g))]
    to_del = [v for v ∈ vs if v ∉ nnbs]
   
    for d in to_del
        for v in collect(vertices(sub_g))
            if !has_prop(sub_g,v,id_prop) || get_prop(sub_g,v,id_prop) == d
                rem_vertex!(sub_g,v)
            end
        end
    end
    return sub_g
end

"""
Load the graph of the network to control
"""
function load_network_graph(graph::MetaGraph)
    ntw = deepcopy(graph)
    set_indexing_prop!(ntw,:eid)
    return ntw
end

"""
Load the graph of the control system
"""
function load_control_graph(graph::MetaGraph)
    ntw = deepcopy(graph)
    #indexing can't be done here because aid has not been assigned
    #set_indexing_prop!(ntw,:aid)
    return ntw
end

"""
Find a set of paths in the network such as a given coverage of node is ensured. e.g. if 0.95 is the coverage, it means that 95% of vertices of the graph are included in the resulting set of paths.
"""

function find_paths_by_seed(seed,g::G,coverage::Float64)where G<: AbstractGraph
    Random.seed!(seed)

    cc = closeness_centrality(g)
    cci = sort([ (i,cc[i]) for i=1:length(cc) ],by=last,rev=true)

    pending = cci 
    cp =[]

        while length(pending) >= (1- coverage) * nv(g)
            pending_i = [ first(p) for p in pending]
            
            #node with the most closeness_centrality
            s = first(first(pending))

            #max distance to any other pending node
            ds = gdistances(g,s)
            sds = sort([(i,ds[i]) for i=1:length(ds) if i in pending_i ],by=last,rev=true)
            d = first(first(sds))

            #shortest path between these two nodes
            sp = first(yen_k_shortest_paths(g,s,d).paths)
            if length(sp) > 2 #only paths with more than 2 nodes
                push!(cp, sp)
            end

            #remove nodes in the shortest path from pending list
            pending_i = collect(setdiff([ first(p) for p in pending ],Set(sp)))
            # println(pending_i)
            pending = [ p for p in pending  if first(p) in pending_i ]
        end
    return cp
end


"""
Given a set of paths, return the start and end vertices
"""
function get_end_points(seed,g::G,coverage::Float64)where G<:AbstractGraph
    return [ (first(p),last(p)) for p in find_paths_by_seed(seed,g,coverage) if first(p) != last(p) ]
end

export get_graph