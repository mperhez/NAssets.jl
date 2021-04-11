export ϕ

@enum ControlModel CENTRALISED=1 DISTRIBUTED=2

function ϕ(t,T,pulse)
    α = 0.5
    Β = 0.5
    if isnothing(pulse)
        new_phase = t > 0 ? t - 1 : T  # phase function
    else
        new_phase = round(α * t + Β)
    end
end
"""
Agent emits pulse
"""
# function pulse(agent,model)
#     if(agent.phase == agent.T)
#         agent.color = :white
#
#         for n in agent.neighbors
#             na = first(filter(a->a.id == n,Set(allagents(model))))
#             push!(na.inbox,(agent.id, model.graph.weights[agent.id,na.id]))
#         end
#     else
#         agent.color = :black
#     end
# end

function update_neighbours(agent,model)
    neighbours = space_neighbors(agent,model,1)
    for n in neighbours
        ag_n = find_agent(n,model)
        push!(ag_n.inbox,agent.id)
    end
end

function pulse(agent,model)
    if(round(agent.phase,digits=2) == model.:Τ)
        agent.color = :white
        update_neighbours(agent,model)
        agent.phase = 0.0
    else
        agent.color = :blue
    end
end


"""
Agent processes pulses "observed"/"received" from neighbors
"""
function process_pulses(agent,model)
    if agent.phase < model.:Τ
        agent.phase = round(agent.phase + 0.1,digits=2)
    else
        agent.phase = round(agent.phase - model.:Τ,digits=2)
    end

    if !isempty(agent.inbox)
        if length(agent.inbox) > agent.maxN
            agent.phase = round(min(model.:Τ,agent.phase+model.:ΔΦ),digits=2)
            agent.maxN = length(agent.inbox)
        elseif length(agent.inbox) == agent.maxN &&
                maximum(agent.inbox) > agent.maxId
            agent.phase = round(min(model.:Τ,agent.phase+model.:ΔΦ),digits=2)
            agent.maxId = maximum(agent.inbox)
        end
    end
agent.inbox = []
end


function pulse_received(pulses,strategy)
    return if length(pulses) > 1
        @match strategy begin
        :NEAR  =>
                # This seems the most sensible, as all are received simoultaneosuly
                # intensity (greater distance less intensity)
                last(sort(pulses,by=x->x[2]))
        :MIXED =>
                #intensity and fraction of time step (distance * index)
                #TODO review: as intensity distance may need to be reversed and then multiplied
                # by index, then get the first.
                last(sort(pulses,by=x->findfirst(isequal(x),pulses)*x[2]))
        _     =>
                #FIFO
                first(pulses)
        end
    elseif isempty(pulses)
        Nothing
    else
        first(pulses)
    end
end

"""
Find agent in the model given the id
"""
function find_agent(id,model)
    first(filter(a->a.id == id,Set(allagents(model))))
end

"""
    load the graph of the network to control
"""

function load_network_graph()
    Random.seed!(123)
    #ntw = smallgraph("house")
    ntw = MetaGraph(watts_strogatz(10,4,0.8))
    set_indexing_prop!(ntw,:eid)
    #gplot(ntw,layout=circular_layout,nodelabel=nodes(ntw))
    return ntw
end


"""
    load the graph of the control system
"""

function load_control_graph()
    Random.seed!(123)
    ntw = MetaGraph(watts_strogatz(10,4,0.8)) #watts_strogatz(25,4,0.8) #complete_graph(1)
    #ntw = MetaGraph( [Int(i) for i in ring_graph(10)])
    #indexing can't be done here because aid has not been assigned
    #set_indexing_prop!(ntw,:aid)
    #gplot(ntw,layout=circular_layout,nodelabel=nodes(ntw))
    return ntw
end

function plot_ctl_network_multi(
    model;
    kwargs...,
)

    nsize = 0.13
    lwidth = 0.5
    
    ctl_p = graphplot(
        model.ctl_graph
        ,names = [ i for i in 1:nv(model.ctl_graph) ]
                #[ get_control_agent(i,model) for i in 1:nv(model.ctl_graph) ]
        , method = :circular
        , curvature_scalar = 0.0
        ,size=(300,200)
        ,node_weights = [ i > 9 ? 1 : 5 for i in 1:nv(model.ctl_graph)]
        ,nodeshape = :circle
        ,nodecolor = [ getindex(model,get_prop(model.ctl_graph, i, :aid)).state.color for i=1:nv(model.ctl_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor=:dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,edgestyle = :dot
        ,titlefontcolor=:white
        ,curves = false
    )
    annotate!((-0.7,0.72,Plots.text("Control Network", 11, :black, :center)))
        
    return ctl_p

end


function plot_ctl_network_mono(
    model;
    kwargs...,
)

    ctl_p = plot(circle_shape(0,0,0.1)
                 , seriestype = [:shape]
                 , lw=0.5 
                 , c=:lightblue
                 , linecolor=:black
                 , legend = false
                 #, fillalpha = 0.5
                 , aspect_ratio = 1
                 , showaxis = false
                 ,xlims=[-1,1]
                 ,ylims=[-1,1]
                 ,grid = false
                 ,ticks=false
                 ,titlefontcolor=:white
                )
    annotate!((-1,0.72,Plots.text("Single Controller", 11, :black, :center)))

    return ctl_p

end

function plotabm_networks(
    model;
    kwargs...
)
    
    l =  @layout([A{0.01h}; [B C ; D E]])  #(2,2) #@layout [a{1w} [grid(1,2) b{0.2h}] ] #@layout [a{1w};(1,2)]

    title = plot(title = "Plot title", grid = false, showaxis = false, ticks=false, bottom_margin = -50Plots.px)

    ctl_p = nv(model.ctl_graph) > 1 ? 
            plot_ctl_network_multi(model;kwargs...) :
            plot_ctl_network_mono(model;kwargs...)
    

    ctl_r = plot_empty()

    ntw_p = plot_asset_networks(model; kwargs)
    
    tpt_p = plot_throughput(model; kwargs)

    p = Plots.plot(title,ctl_p,ctl_r,ntw_p,tpt_p, layout=l, size=(800,600))
    
    return p
end


function plot_asset_networks(
    model;
    kwargs...
)
    
    nsize = 0.4
    lwidth = 0.5

    ntw_p = graphplot(
        model.ntw_graph
        ,names = [get_eid(i,model) for i=1:nv(model.ntw_graph)]
        , method = :circular
       # ,size=(300,200)
        ,node_weights = [ get_eid(i,model) > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]  #[ i > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]
        ,nodeshape = :hexagon
        ,nodecolor = [ is_up(getindex(model,get_eid(i,model))) ? :lightgray : :red for i in 1:nv(model.ntw_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor= model.ticks < 1 ? :red : :dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,palette = [:lightgray, :red]
        #,titlefontsize=1
        ,titlefontcolor=:white
    )
    
    annotate!((-0.7,0.75,Plots.text("Asset Network", 11, :black, :center)))

    return ntw_p
end


function plot_empty()
    return plot(title="false", titlefontcolor=:white ,showaxis = false, ticks=false,grid=false)
end

function plot_throughput(
    model;
    kwargs...
)

    tpt_p = plot(title="tpt",titlefontcolor=:white,ylims=[0,60])
    for i=1:nv(model.ntw_graph)
        sne = getindex(model,get_eid(i,model))
        # v_pkt_in = [ s.in_pkt * model.:pkt_size for s in sne.state_trj ]
        tpt_v = get_throughput_up(sne,model)#isempty(v_pkt_in) ? [0] : get_throughput(v_pkt_in,10)
        tpt_p = plot!(tpt_v,xlims=[0,model.N], linealpha=0.5
        # , line=:stem
        ,legend = :outerright
        )
    end

    annotate!((-1,33,Plots.text("Throughput", 11, :black, :center)))

    return tpt_p
end



function get_control_agent(asset_id::Int,model)
    return model.mapping_ctl_ntw[asset_id]
end

function get_controlled_assets(agent_id::Int,model)
    assets = filter(k->model.mapping_ctl_ntw[k] == agent_id,keys(model.mapping_ctl_ntw))
    #println("assets controlled by $(agent_id) are: $(length(assets))")
    return assets
end



function set_control_agent!(asset_id::Int, agent_id::Int, model)
    getindex(model,asset_id).controller_id = agent_id
    #TODO Consider removing this line below
    #To avoid putting info in model
    model.mapping_ctl_ntw[asset_id] = agent_id
end

function soft_drop_node(model)
    #-1 pick node to remove
    #0 on_switch event
    #1remove from network
    #2in controller: update topology and paths
    #in switch detect path/port not available and ask controller
    g = model.ntw_graph
    dpn_ids = [3] # dropping node id
    dpt = 80 # dropping time

    if model.ticks == dpt

        for dpn_id in dpn_ids
            dpn_ag = getindex(model,dpn_id)
            set_down!(dpn_ag)

            for nb in all_neighbors(model.ntw_graph,get_address(dpn_id,g))
                sne = getindex(model,get_eid(nb,model))
                link_down!(sne,dpn_id,model)
            end
            
            aid = get_control_agent(dpn_id,model)
            a = getindex(model,aid)
            link_down!(a,dpn_id,model)

            #soft remove 
            model.ntw_graph = soft_remove_vertex(g,get_address(dpn_id,g))
            
        end
        
        
    end
    
end



function hard_drop_node(model)
    #-1 pick node to remove
    #0 on_switch event
    #1remove from network
    #2in controller: update topology and paths
    #in switch detect path/port not available and ask controller

    dpn_ids = [3] # dropping node id
    dpt = 80 # dropping time

    if model.ticks == dpt

        for dpn_id in dpn_ids
            for nb in all_neighbors(model.ntw_graph,get_address(dpn_id,model.ntw_graph))
                link_down!(get_eid(nb,model),dpn_id,model)
            end
            #remove 
            dpn_ag = getindex(model,dpn_id)
            #kill_agent!(dpn_ag,model)
            set_down!(dpn_ag)
            delete!(model.mapping_ctl_ntw,dpn_id)
            #remove_vertices!(model.ntw_graph,[get_address(i,model) for i in dpn_ids])
            model.ntw_graph = remove_vertex(model.ntw_graph,get_address(dpn_id,model.ntw_graph))
            update_addresses_removal!(dpn_id,model)
        end
        
        
    end
    
end

function soft_remove_vertex(g::AbstractGraph,dpn_id::Int)
    
    new_g = deepcopy(g)
    nbs₀ = deepcopy(all_neighbors(new_g,dpn_id))

    for nb in nbs₀
        rem_edge!(new_g,dpn_id,nb)
        rem_edge!(new_g,nb,dpn_id)
    end

    println("Links of $dpn_id removed => $(all_neighbors(new_g,dpn_id))")

    [println(" new g: $v => Props: $(get_prop(new_g,v,:eid))") for v in vertices(new_g)]
    # sm_g = sparse(g)
    # sm_new_g = deepcopy(sm_g)

    # [ if i == dpn_id || j == dpn_id ; sm_new_g[i,j] = 0 end for i=1:nv(g), j=1:nv(g)]

    # new_g = MetaGraph(sm_new_g)

    # for v in vertices(g)
    #     set_props!(new_g,v,props(g,v))
    # end

    # for i=1:nv(g)
    #     for j=1:nv(g)
    #         if i == dpn_id || j == dpn_id
    #             new_ntw[i,j] = 0
    #         end
    #     end
    # end
    #[i >=dpn_id ? labels[i] = i+1 : labels[i] = i  for i in keys(labels)]
    return new_g#
end

function remove_vertex(g::AbstractGraph,dpn_id::Int)
    sm_g = sparse(g)
    sm_new_g = spzeros((nv(g)-1),(nv(g)-1))
    for i=1:nv(g)
        for j=1:nv(g)
            #println(" $i,$j value: $(sparse(ntw)[i,j])")
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
Given a SimNE id it returns its ntw node address.
"""
function get_address(eid::Int,g::AbstractGraph)::Int
    #res = filter(p->p[2] == eid,pairs(model.mapping_ntw_sne))
    #return !isempty(res) ? first(keys(res)) : -1
    return g[eid,:eid]
end

"""
Given a ntw node address it returns the corresponding SimNE id
"""
function get_eid(address::Int,model)::Int
    return model.mapping_ntw_sne[address]
end

function update_sne_address!(eid::Int,new_address::Int,model)
    #curr_address = get_address(eid,model)
    model.mapping_ntw_sne[new_address] = eid
end

"""
Update (ntw node) addresses of SimNE agents after removal of a given SimNE
"""
function update_addresses_removal!(dpn_id::Int,model)
    available_addr = get_address(dpn_id,model.ntw_graph)
    #println("Current length of g: $(nv(model.ntw_graph))")
    for addr::Int=available_addr:nv(model.ntw_graph)
        #println("Address $addr and its type: $(typeof(addr))")
        update_sne_address!(
            get_eid(addr+1,model),
            addr,
            model
            )
    end
    delete!(model.mapping_ntw_sne,length(model.ntw_graph)+1)
end

function circle_shape(h,k,r)
    θ = LinRange(0,2*π, 500)
    h .+ r*sin.(θ), k .+ r*cos.(θ)
end

function do_agent_step!(a::SimNE,model)
    #Process OF messages (packet data traffic)
    is_up(a) && is_ready(a) ? in_packet_processing(a,model) : nothing #println("queue of $(a.id) is empty")
end

function do_agent_step!(a::Agent,model)

    # Process asset-agent messages
    
    ## Process OF Messages (SimNE to (sdn) control messages)
    is_up(a) && is_ready(a) ? in_packet_processing(a,model) : nothing #println("queue of $(a.id) is empty")

    # Process inter-agent messages

    do_receive_messages(a,model)


    #Find the shortest path

    ctl_g = a.params[:ctl_graph]
    controlled = get_controlled_assets(a.id,model)
    my_v = 0
    for v in vertices(ctl_g)
        if get_prop(ctl_g,v,:aid) == a.id
            my_v = v
        end
        # println(" Agent $(a.id) => props of node $v are: $(props(ctl_g, v))")
    end
    for c in controlled
        #v = get_prop(ctl_g,c,:eid)
        # [ println("CTL Ag $(a.id) graph has nodes: $(get_prop(ctl_g,nb,:aid))") for nb in neighbors(ctl_g,my_v)]
    end

    

end

"""
    Receives inter-agent messages
"""
function do_receive_messages(a::Agent,model)
    #TODO: check if another periodicity is required, rather than every tick
    #if !isempty(a.msgs_in) println("[$(model.ticks)]($(a.id)) in msgs: $(a.msgs_in)") end
    for msg in a.msgs_in
        process_msg!(a,msg,model)
    end
end

function do_send_messages(a::Agent,model)
    g = a.params[:ctl_graph]
    # In this graph a is always node 1
    nbs = neighbors(g,1)

    for nb in nbs
        rid = get_prop(g,nb,:aid)
        send_msg!(a.id,rid,msg)
    end

end

# """
#     Search for a given ntw host using local information available
# """
# function local_search(g::MetaGraph,tids::Array{Int},model)
    
#     #looking for node 5, i am 1, 
#     # is in my local graph? what is goodness of each option?
#     # if is in local graph -> unicast to node
#     # if not, -> use pheromone to decide where to send msg, if not available then broadcast



#     #local graph
#     target = (0,0)
#     # looks in ntw_graph it knows
#     for tid in tids
#         for v in vertices(g)
#             eid = get_prop(g,v,:eid)
#             if eid == tid
#                 target = (v,eid)
#                 #install rule in sne?
#                 break
#             end
#         end
#     end
    
#     # I found the controller, but that it might not mean they are connected in ntw

#     return target
    
# end


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



"""
Search for a path between nodes s and d in the local graph lg
It assumes property :eid of each vertex is global id of vertex
"""

function query_path(lg,s,d)
    ls = to_local_vertex(lg,s)
    ld = to_local_vertex(lg,d)
    result =   LightGraphs.YenState{Float64,Int64}([],[])
    path = []
    
    if ls > 0 && ld > 0
        #slg = SimpleGraph(lg)
        #return yen_k_shortest_paths(slg,ls,ld, weights(slg),2,Inf)
        result = yen_k_shortest_paths(lg,ls,ld)
    end
    #gvs = [ lg[v,:eid] for v in vertices(lg)]
    #println("network contains: gvs: $gvs")
    #println("query_path:  g v: $(vertices(lg)), s: $(s) - ls: $(ls), d: $d - ld $ld result ==> $(result)")

    if !isempty(result.paths)
        path = result.paths
        path = !isempty(path) && typeof(path) == Array{Array{Int64,1},1} ? first(path) : path
        path = [ lg[v,:eid] for v in path]
        result =   LightGraphs.YenState{Float64,Int}([length(path)],[path])
    end

    return result
end


"""
    Local search receiving source and destination in a tuple
"""
function query_path(lg,t)
    query_path(lg,first(t),last(t))
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
    g = MetaGraph(m)
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
    #println("Creating subgraph egs: $(egs) and eqv: $eqv")
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

#TODO: delete
# for e in egs

#     s_gid = last(first([ x for x in eqv if first(x) == src(e)]))
    
#     if !has_vertex(g,src(e))
#         add_vertex!(g,gid_prop,gs)
#     end

#     d_gid = last(first([ x for x in eqv if first(x) == dst(e)]))
    
#     if !has_vertex(g,dst(e))
#         add_vertex!(g,gid_prop,gd)
#     end
#     ls = to_local_vertex(g,gs)
#     ld = to_local_vertex(g,gd)
#     add_edge!(g,ls,ld)
#     add_edge!(g,ld,ls)
# end












"""
    Plots a subgraph that is part of a greater one
    global ids in property :eid.
"""
function plot_subg(sg)
    return graphplot(sg
                    ,names = [ get_prop(sg,i,:eid) for i=1:nv(sg)]
          )
end

"""
    Return one path for each 
"""
function all_k_shortest_paths(g::MetaGraph)
    ps = [ (g[s,:eid],g[d,:eid]) for s in vertices(g), d in vertices(g) if s < d]
    return query_path.([g], ps)
end

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