export ϕ

@enum GraphModel begin
    CUSTOM=0
    CENTRALISED=1 # Only for control model
    RING=2
    COMPLETE=3
    GRID=4
    STAR=5
    BA_RANDOM=6 # Barrabasi_Albert
    WS_RANDOM=7 # watts_strogatz
    #SM_RANDOM_TOPO=8 # Stochastic Block Model
end


"""
    Log info msg
"""
function log_info(msg)
    #st = string(stacktrace()[2])
    #file_name = lstrip(st[last(findlast("at ",st)):end])
    #file_name = split(file_name,":")
    # file_name = lstrip(st[last(findlast("at ",st)):last(findlast(":",st))-1])
    #method_name = lstrip(st[1:last(findfirst("(",st))-1])
    # logger = get_logger(file_name * "|" * method_name)
    # @info(file_name * "]" * msg)
    #@info msg _module="" _file= replace(first(file_name),".jl"=>"") _line=parse(Int64,last(file_name))
    @info msg
end

"""
    logs an info msg for tick and agent_id passed
"""
function log_info(t,aid,msg)
    @info "[$(t)]($(aid)) $msg"
end

"""
logs only for a given agent
"""
function log_info(t,aid,only_id,msg)
    if aid == only_id
        @info "[$(t)]($(aid)) $msg"
    end
end

"""
    logs an info msg for tick passed
"""
function log_info(t,msg)
    @info "[$(t)] $msg"
end

function log_debug(t,aid,msg)
    @debug "[$(t)]($(aid)) $msg"
end

function log_debug(t,msg)
    @debug "[$(t)] $msg"
end

function log_debug(msg)
    @debug msg
end


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

function get_graph(seed,size,topo;k=0,Β=0,custom_topo=nothing)
    Random.seed!(seed)
    ntw = @match topo begin
        GraphModel(0)=> custom_topo
        GraphModel(2) => MetaGraph( [Int(i) for i in ring_graph(size)])
        GraphModel(3) => MetaGraph(LightGraphs.complete_graph(size))
        GraphModel(4) => MetaGraph( [Int(i) for i in grid2(Int(sqrt(size)))])
        GraphModel(5) => MetaGraph( [Int(i) for i in Laplacians.star_graph(size)] )
        GraphModel(6) => MetaGraph(barabasi_albert(size,k))
        GraphModel(7) => MetaGraph(watts_strogatz(size,k,Β))
        #GraphModel(8) => MetaGraph(stochastic_block_model())
    end
end

"""
    load the graph of the network to control
"""

function load_network_graph(graph::MetaGraph)
    ntw = deepcopy(graph)
    set_indexing_prop!(ntw,:eid)
    return ntw
end

"""
    load the graph of the control system
"""

function load_control_graph(graph::MetaGraph)
    Random.seed!(seed)
    ntw = deepcopy(graph)
    #indexing can't be done here because aid has not been assigned
    #set_indexing_prop!(ntw,:aid)
    return ntw
end

function plot_ctl_network_multi(
    model;
    kwargs...,
)

    nsize = 0.13
    lwidth = 0.5

    method = model.ctrl_model == GraphModel(4) ? :sfdp : :circular
    Random.seed!(model.seed)

    ctl_p = graphplot(
        model.ctl_graph
        ,names = [ i for i in 1:nv(model.ctl_graph) ]
                #[ get_control_agent(i,model) for i in 1:nv(model.ctl_graph) ]
        ,method = method#:sfdp#:stress#:shell# #:spectral #:circular
        #TODO check if required, not working atm
        #,func = NetworkLayout.SFDP.layout(adjacency_matrix(model.ctl_graph),2)
        , curvature_scalar = 0.0
        ,size=(300,200)
        ,node_weights = [ i > 9 ? 1 : 5 for i in 1:nv(model.ctl_graph)]
        ,nodeshape = :circle
        ,nodecolor = [ has_active_controlled_assets(
                        getindex(model,model.ctl_graph[i,:aid]),model
                       ) ? :lightblue : :lightgray for i in 1:nv(model.ctl_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor=:dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,edgestyle = :dot
        ,titlefontcolor=:white
        ,curves = false
    )
    #TODO replace buggy annotation not thread-safe
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

function plot_ctl_throughput(
    model;
    kwargs...
)
    tpt_v = get_ag_msg(model)
    max_y = maximum(tpt_v)+5
    tpt_p = plot(title="tpt",titlefontcolor=:white,ylims=[0,max_y])
    # for i=1:nv(model.ctl_graph)
    #     a = getindex(model,model.ctl_graph[i,:aid])
        # tpt_v = get_throughput_up(a,model)
    
    # log_info("Plotting...")
    # log_info(tpt_v)
    tpt_p = plot!(tpt_v,xlims=[0,model.N], linealpha=0.5
        # , line=:stem
        ,ylabel = "Quantity of agent messages"
        ,legend = false#:outerright
        )
    # end

    annotate!((3*(model.N/4),max_y+1,Plots.text("Control Msgs", 11, :black, :center)))

    return tpt_p
end

function plot_asset_networks(
    model;
    kwargs...
)
    
    nsize = 0.4
    lwidth = 0.5

    method = :circular #model.ntw_model == #GraphModel(4) ? :sfdp : :circular
    Random.seed!(model.seed)

    edge_color_dict = Dict()
    edge_width_dict = Dict()
    edge_style_dict = Dict()

    for e in edges(model.ntw_graph)
        if model.ticks > 0
            if is_active_flow((e.src,e.dst),model)
                edge_color_dict[(e.src,e.dst)] = :green
                edge_width_dict[(e.src,e.dst)] = 3
                edge_style_dict[(e.src,e.dst)] = model.ticks % 3 > 0 ? model.ticks % 3 > 1 ? :dashdot : :solid : :dot
            else
                edge_color_dict[(e.src,e.dst)] = :dimgray
                edge_width_dict[(e.src,e.dst)] = 1
                edge_style_dict[(e.src,e.dst)] = :solid
            end
        else
            edge_color_dict[(e.src,e.dst)] = :red
            edge_width_dict[(e.src,e.dst)] = 1
            edge_style_dict[(e.src,e.dst)] = :solid
        end
        
    end

    ntw_p = graphplot(
        model.ntw_graph
        ,names = [get_eid(i,model) for i=1:nv(model.ntw_graph)]
        , method = method
       # ,size=(300,200)
        ,node_weights = [ get_eid(i,model) > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]  #[ i > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]
        ,nodeshape = :hexagon
        ,nodecolor = [ is_up(getindex(model,get_eid(i,model))) ? :lightgray : :red for i in 1:nv(model.ntw_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor= edge_color_dict
        ,edgewidth= edge_width_dict
        ,edgestyle = edge_style_dict
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
    max_y = 100
    tpt_p = plot(title="tpt",titlefontcolor=:white,ylims=[0,max_y])
    for i=1:nv(model.ntw_graph)
        sne = getindex(model,get_eid(i,model))
        # v_pkt_in = [ s.in_pkt * model.:pkt_size for s in sne.state_trj ]
        tpt_v = get_throughput_up(sne,model)#isempty(v_pkt_in) ? [0] : get_throughput(v_pkt_in,10)
        tpt_p = plot!(tpt_p,tpt_v
        ,xlims=[0,model.N]
        , linealpha=0.5
        # , line=:stem
        ,label = "$i"
        ,ylabel = "MB"
        ,legend = :outerright
        )
    end
    #TODO: This annotation breaks the multithreading as it does not receive the plot object, it seems to take the last one, which might clash among threads.
    annotate!((3*(model.N/4),max_y+1,Plots.text("Throughput ($(model.interval_tpt) steps)", 11, :black, :center)))

    return tpt_p
end


function plotabm_networks(
    model;
    kwargs...
)
    
    l =  @layout([A{0.01h}; [B C ; D E]])  #(2,2) #@layout [a{1w} [grid(1,2) b{0.2h}] ] #@layout [a{1w};(1,2)]

    title = plot(title = "Plot title", grid = false, showaxis = false, ticks=false, bottom_margin = -50Plots.px)

    ctl_p = model.ctrl_model != GraphModel(1) ? # Centralised
            plot_ctl_network_multi(model;kwargs...) :
            plot_ctl_network_mono(model;kwargs...)
    

    ctl_r = model.ctrl_model != GraphModel(1) ? plot_ctl_throughput(model; kwargs) : plot_empty()

    ntw_p = plot_asset_networks(model; kwargs)
    
    tpt_p = plot_throughput(model; kwargs)

    p = Plots.plot(title,ctl_p,ctl_r,ntw_p,tpt_p, layout=l, size=(800,600))
    
    return p
end


function get_control_agent(asset_id::Int,model)
    return model.mapping_ctl_ntw[asset_id]
end

function get_controlled_assets(agent_id::Int,model)
    assets = filter(k->model.mapping_ctl_ntw[k] == agent_id,keys(model.mapping_ctl_ntw))
    #log_info("assets controlled by $(agent_id) are: $(length(assets))")
    return assets
end

function has_active_controlled_assets(agent::Agent,model)
    assets = get_controlled_assets(agent.id,model)

    sum_up = sum([ is_up(getindex(model,sne)) for sne in assets ])
    return sum_up > 0 ? true : false
end



function set_control_agent!(asset_id::Int, agent_id::Int, model)
    getindex(model,asset_id).controller_id = agent_id
    #TODO Consider removing this line below
    #To avoid putting info in model
    model.mapping_ctl_ntw[asset_id] = agent_id
end

function soft_drop_node!(model)
    #-1 pick node to remove
    #0 on_switch event
    #1remove from network
    #2in controller: update topology and paths
    #in switch detect path/port not available and ask controller
    
    # dropping node id
    # dropping time
    dn = model.dropping_nodes
    if haskey(dn,model.ticks)
        dpn_ids = dn[model.ticks]
        for dpn_id in dpn_ids
            g = model.ntw_graph
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

    # log_info("Links of $dpn_id removed => $(all_neighbors(new_g,dpn_id))")

    # [log_info(" new g: $v => Props: $(get_prop(new_g,v,:eid))") for v in vertices(new_g)]
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
    #log_info("Current length of g: $(nv(model.ntw_graph))")
    for addr::Int=available_addr:nv(model.ntw_graph)
        #log_info("Address $addr and its type: $(typeof(addr))")
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
    # log_info("[$(model.ticks)]($(a.id)) start step")
    #log_info(model.ticks,a.id, "start step")
    is_up(a) && is_ready(a) ? in_packet_processing(a,model) : nothing #log_info("queue of $(a.id) is empty")
    # @debug("[$(model.ticks)]($(a.id)) end step")
end

function do_agent_step!(a::Agent,model)
    # @debug("[$(model.ticks)]($(a.id)) start step")
    # Process asset-agent messages
    
    ## Process OF Messages (SimNE to (sdn) control messages)
    is_up(a) && is_ready(a) ? in_packet_processing(a,model) : nothing #log_info("queue of $(a.id) is empty")

    # Process inter-agent messages

    do_receive_messages(a,model)


    #Find the shortest path

    # ctl_g = a.params[:ctl_graph]
    # controlled = get_controlled_assets(a.id,model)
    # my_v = 0
    # for v in vertices(ctl_g)
    #     if get_prop(ctl_g,v,:aid) == a.id
    #         my_v = v
    #     end
    #     # log_info(" Agent $(a.id) => props of node $v are: $(props(ctl_g, v))")
    # end
    # for c in controlled
    #     #v = get_prop(ctl_g,c,:eid)
    #     # [ log_info("CTL Ag $(a.id) graph has nodes: $(get_prop(ctl_g,nb,:aid))") for nb in neighbors(ctl_g,my_v)]
    # end

    if !isempty(get_state(a).active_paths)
        log_info(model.ticks,a.id,"-->$(get_state(a).active_paths)")
    end

end

"""
    Receives inter-agent messages
"""
function do_receive_messages(a::Agent,model)
    #TODO: check if another periodicity is required, rather than every tick
    #if !isempty(a.msgs_in) log_info("[$(model.ticks)]($(a.id)) in msgs: $(a.msgs_in)") end

    #senders = [ m.sid for m in a.msgs_in ]
    #log_info("[$(model.ticks)]($(a.id)) has $(length(a.msgs_in)) msgs to process from $senders" )

    if model.ctrl_model != GraphModel(1)
        for msg in a.msgs_in
            #log_info(msg)
            process_msg!(a,msg,model)
        end
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
    #log_info("network contains: gvs: $gvs")
    # log_info("query_path:  g v: $(vertices(lg)), s: $(s) - ls: $(ls), d: $d - ld $ld result ==> $(result)")

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

function record_benchmark!(bdir,run_label,aid,query_time,query,query_graph,query_paths)
    
    if !isdir(bdir)
       mkdir(bdir) 
    end
    #benchmark block start
    b = @benchmark begin 
        do_query($query_time,$query,$query_graph,$query_paths)
    end
    serialize( bdir * run_label *"_$(first(query))_$(last(query))_$(query_time)_$(aid)_bchmk.bin",b)
    #benchmark block end
end

## main functions

new_config(seed,ctl_model,ntw_topo,size,n_steps,drop_proportion,prob_random_walks,benchmark, animation,k,Β,ctl_k,ctl_Β) =
    return ( seed = seed
            ,ctl_model=ctl_model
            ,ntw_topo = ntw_topo
            ,size=size
            ,n_steps=n_steps
            ,drop_proportion=drop_proportion
            ,prob_random_walks = prob_random_walks
            ,benchmark = benchmark
            ,animation = animation
            ,k=k
            ,Β = Β
            ,ctl_k=ctl_k
            ,ctl_Β = ctl_Β
            ,custom_topo = nothing
            ,ctl_custom_topo = nothing
            )

function get_dropping_nodes(drop_proportion)
    #TODO calcualte according to proportion
    return Dict(80=>[3]
    #,120=>[2]
    ) # drop time => drop node
end

function load_run_configs() 
    configs = []
    for ctl_model in [GraphModel(1)]#, ControlModel(4) ] #instances(ControlModel)
        for ntw_topo in [GraphModel(4)]
            for size in [16]#, 50, 100]
                for drop_proportion in [10]
                    for seed in [123]
                        ks = ntw_topo == GraphModel(6) ||
                            ntw_topo == GraphModel(7) ? [4] : [0]
                        ctl_ks = ctl_model == GraphModel(6) ||
                                ctl_model == GraphModel(7) ? [4] : [0]
                        Βs = ntw_topo == GraphModel(6) ||
                                ntw_topo == GraphModel(7) ? [0.8] : [0.0]
                        ctl_Βs = ctl_model == GraphModel(6) ||
                                    ctl_model == GraphModel(7) ? [0.8] : [0.0]
                        
                        for k in ks
                            for Β in Βs
                                for ctl_k in ctl_ks
                                    for ctl_Β in ctl_Βs
                                        push!(configs,new_config(seed,ctl_model,ntw_topo,size,200,drop_proportion,1.0,false,true,k,Β,ctl_k,ctl_Β))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return configs
end

function get_run_label(config)
    base_label = "$(config.ntw_topo)"
    if config.ntw_topo == GraphModel(6) ||
    config.ntw_topo == GraphModel(7)
        base_label = base_label * "_$(config.k)_$(replace(string(config.Β),"."=>""))"
    end

    base_label = base_label * "_$(config.ctl_model)"

    if config.ctl_model == GraphModel(6) ||
        config.ctl_model == GraphModel(7)
        base_label = base_label * "_$(config.ctl_k)_$(replace(string(config.ctl_Β),"."=>""))"
    end
   
    run_label = base_label * "_$(config.size)_$(config.seed)_$(replace(string(config.prob_random_walks),"."=>""))"

    return run_label
end
function single_run(config)
    Random.seed!(config.seed)
    args = Dict()
    params = Dict()
    args[:N]=config.n_steps
    args[:Τ]=config.size
    args[:ΔΦ]=1
    ntw_graph = load_network_graph(get_graph(config.seed,config.size,config.ntw_topo;k=config.k,Β=config.Β,custom_topo=config.custom_topo))
    args[:ntw_graph]=ntw_graph
    args[:dropping_nodes]= get_dropping_nodes(config.drop_proportion)
    args[:ctrl_model] = config.ctl_model
    args[:ntw_model] = config.ntw_topo

    args[:seed] = config.seed
    args[:benchmark] = config.benchmark
    args[:animation] = config.animation
    args[:prob_random_walks] = config.prob_random_walks

    q_ctl_agents = 0
    run_label = get_run_label(config)
    args[:run_label] = run_label
    if config.ctl_model == GraphModel(1)
        args[:ctl_graph] = MetaGraph()
        q_ctl_agents = 1
    else
        ctl_graph = get_graph(config.seed,config.size,config.ctl_model;k=config.ctl_k,Β=config.ctl_Β,custom_topo=config.ctl_custom_topo)
        # ctl_graph = load_control_graph(config.ctl_model,nv(ntw_graph),config.seed)
        args[:ctl_graph]=ctl_graph
        q_ctl_agents = nv(ctl_graph)
    end

    q_agents = nv(ntw_graph)+q_ctl_agents
    args[:q]=q_agents

    adata = [get_state_trj,get_condition_ts, get_rul_ts]
    mdata = [:mapping_ctl_ntw,get_state_trj]
    result_agents,result_model = run_model(config.n_steps,args,params; agent_data = adata, model_data = mdata)
    
    ctl_ags = last(result_agents[result_agents[!,:id] .> nv(ntw_graph) ,:],q_ctl_agents)[!,"get_state_trj"]
    nes = last(result_agents[result_agents[!,:id] .<= nv(ntw_graph) ,:],nv(ntw_graph))[!,"get_state_trj"]
    
    nes_1 = vcat([ [ split(string(j-1)*";"*replace(to_string(nes[i][j]),"NetworkAssetState(" => ""),";") for j=1:length(nes[i])] for i=1:length(nes) ]...)

    ctl_ags_1 = vcat([ [ split(string(j-1)*";"*replace(to_string(ctl_ags[i][j]),"ControlAgentState(" => ""),";") for j=1:length(ctl_ags[i])] for i=1:length(ctl_ags) ]...)
    
    #sdir = data_dir*"runs2/$(config.ctl_model)/"
    sdir = data_dir*"runs3/"

    if !isdir(sdir)
        mkdir(sdir) 
     end
    serialize( sdir * run_label * "_steps_ctl_agents.bin",ctl_ags)
    serialize( sdir * run_label * "_steps_nelements.bin",nes)
    # nwords = Dict(1=>"one",2=>"two",3=>"three",4=>"four",5=>"five",6=>"six",7=>"seven",8=>"eight",9=>"nine",0=>"zero", 10=>"ten")

    # for i in 1:length(ctl_ags)
    #     for j in  1:length(ctl_ags[i])
    #         #log_info("$i - $j -> $(ctl_ags[i][j].a_id)")
    #         ij_paths = ctl_ags[i][j].paths
            
    #         # txt = objecttable(ctl_ags[i][j].paths)
    #         #::Dict{Symbol,Array{Tuple{Int64,Float64,Array{Int64}}}}
    #         ij_d::Dict{Symbol,Array{Int64}} = Dict()
    #         for k in keys(ij_paths)
    #             # ij_d[ Symbol("$(k[1])_$(k[2])") ] = [1]
                
    #             ij_d[ Symbol("$(nwords[k[1]])_$(nwords[k[2]])") ] = [1]
    #         end
    #         log_info("$i - $j -> $(keys(ij_d))")
    #         txt = objecttable(ij_d)
    #         log_info("$i - $j -> $txt")
    #     end
    # end
    
    # js_ctl_agents = objecttable(ctl_ags)

    ctl_ags_1 = [ replace.(ctl_ags_1[i]," Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64,N} where N},N} where N}" => "") for i=1:1]#length(ctl_ags_1) ]

    # ctl_ags_1 = [filter(x -> x .!= " ", ctl_ags_1[i]) for i=1:length(ctl_ags_1) ]

    
    nes_condition = last(result_agents,q_agents)[!,"get_condition_ts"]
    nes_rul = last(result_agents,q_agents)[!,"get_rul_ts"]

    # log_info(ags_condition)

        # for i=1:size(ags_condition,1)#nv(ntw_graph)
        #     log_info("testing $i ...")
        #     log_info(ags_condition[i])
        #     #log_info(hcat([i 1; i 2 ; i 3] , ags_condition[i]),';')
        # end

    open(sdir * run_label * "_condition_nelements.csv", "w") do io
        for i=1:nv(ntw_graph)
            writedlm(io,hcat([i 1; i 2 ; i 3] , nes_condition[i]),';')
        end
    end;


    open(sdir * run_label * "_rul_neselements.csv", "w") do io
    #     #for i=1:nv(ntw_graph)
            writedlm(io,nes_rul[1:10],';')
    #     #end
    end;

    model_data = last(result_model)["get_state_trj"]
    model_data = [ (m.tick,m.links_load) for m in model_data ]

    #ags_1 = [ split(string(i-1)*";"*replace(to_string(ags[j][i]),"NetworkAssetState(" => ""),";") for j=1:length(ags)] for i=1:length(ags[j]) ]
    open(sdir * run_label * "_steps_nelements.csv", "w") do io
        # writedlm(io, ["tick" "id" "up" "ports_edges" "pkt_in" "pkt_out" "pkt_drop" "flows"], ';')
        writedlm(io,reshape(vcat(["tick"],string.([i for i in fieldnames(NetworkAssetState)])),1,length(fieldnames(NetworkAssetState))+1),';')
        writedlm(io,nes_1,';') 
    end;
    

    # open(data_dir*"runs/$(config.ctl_model)/"*"$(config.size)_$(config.seed)_steps_ctl_agents.json", "w") do io
    #     write(io, js_ctl_agents)
    #  end

    open(sdir * run_label * "_steps_ctl_agents.csv", "w") do io
        # writedlm(io, ["tick" "id" "up" "paths" "in_ag_msg" "out_ag_msg" "in_of_msg" "out_of_msg" "q_queries" ], ';')
        writedlm(io,reshape(vcat(["tick"],string.([i for i in fieldnames(ControlAgentState)])),1,length(fieldnames(ControlAgentState))+1),';')
        writedlm(io,ctl_ags_1,';') 
    end;


    open(sdir * run_label * "_steps_model.csv", "w") do io
        writedlm(io,model_data,';') 
    end;

end

"""
Clears cache of control agent
"""
function clear_cache!(a::Agent,model::ABM)
    if model.ctrl_model != GraphModel(1) && model.ticks - a.params[:last_cache_graph] == model.clear_cache_graph_freq
        a.params[:ntw_graph] = a.params[:base_ntw_graph]
        a.params[:last_cache_graph] = model.ticks
    end

end

function clear_cache!(sne::SimNE,model::ABM)
    #placeholder
end

function to_string(s)
    sep = "; "
    return join([getfield(s,a) for a in fieldnames(typeof(s))],sep)
end


# function get_logger(log_name)
#     return haskey(loggers,log_name) ? loggers[log_name] : init_logger(log_name)
# end

# function init_logger(log_name)
#     loggers[log_name] = getlogger(log_name)
#     setlevel!(loggers[log_name], "info")
#     push!(loggers[log_name],getlogger(name="root"))
#     # push!(loggers[log_name], DefaultHandler(tempname(), DefaultFormatter("[{date} | {level} | {name}]: {msg}")))
#     return loggers[log_name]
# end