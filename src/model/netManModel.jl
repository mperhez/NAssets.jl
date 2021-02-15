"""
Basic initialization
"""
function initialize(args,user_props;grid_dims=(3,3),seed=0)
    pulses = []
    for i in 1:args[:q]
        push!(pulses,[])
    end

    # Global model props
    default_props = Dict(
        :ticks => 0,# # time unit
        :pkt_id => 0,
        :pulses=>pulses,
        :Τ => args[:Τ], # Max time steps to fire
        :ΔΦ => args[:ΔΦ],
        :ntw_graph => args[:ntw_graph],
        :ctl_graph => args[:ctl_graph],
        :mapping_ctl_ntw => Dict{Int64,Int64}(), # mapping between (Ctl) Agent and SimNE
        :mapping_ntw_sne => Dict{Int64,Int64}(), #mapping btwn the underlying network and the corresponding simNE agent 
        :pkt_per_tick => 500, # How many packets are processsed per tick
        :ctrl_model => CENTRALISED,
        :pkt_size => 1500,
        :freq => 30 # frequency of monitoring
    )

    Random.seed!(seed)
    props = merge(default_props,user_props)

    #space = GridSpace(grid_dims, moore=true)
    space = GraphSpace(props[:ntw_graph])
    agent_types = Union{SimNE,Agent}
    model = ABM(agent_types, space; scheduler = random_activation, properties = props)

    #create 
    create_agents!(model)
    model
end

"""
Simplest create agents
"""

function create_agents!(model)
    a_params = Dict(:pkt_per_tick=>model.pkt_per_tick)    
    # create SimNE
    for i in 1:nv(model.properties[:ntw_graph])
        #next_fire = rand(0:0.2:model.:Τ)
        s0 = NetworkAssetState(zeros(2,2))
        id = nextid(model)
        # @show i
        a = add_agent_pos!(
                SimNE(id,i,s0,a_params),model
            )
        # create initial mapping btwn network and SimNE
        model.mapping_ntw_sne[i] = i   
    end

    #create control agents 1:1
    for i in 1:nv(model.properties[:ctl_graph])
        #next_fire = rand(0:0.2:model.:Τ)
        s0 = SDNCtlAgState(zeros((2,2)),Vector{Float64}())
        id = nextid(model)
        a = add_agent_pos!(
                Agent(id,i,s0,a_params),model
            )
        ##assign controller to SimNE
        if model.ctrl_model == CENTRALISED
            for j in 1:nv(model.properties[:ntw_graph])
                set_control_agent!(j,id,model)    
            end
        else
            set_control_agent!(i,id,model)
        end
    end

    

    init_agents!(model)
    # for i in 1:nv(model.properties[:ntw_graph])
    #     @show get_node_agents(i, model)
    # end

end



"""
    It advance model one step. Agents are progressed here to ensure that one action is perform in
    all agents before the next action is performed in all agents, instead of having one action
    executed in some agents and then some start with second action.
"""
function model_step!(model)
    model.ticks += 1
    #@show model.ticks
    
    generate_traffic(model)
    #print("Has sent packet to $(sne.id)")

   # @show model.ticks
    for a in allagents(model)
    #     #pulse(a,model)
    #     println(a.state.condition_trj)
        # @match a begin
        #     a::SimNE => 
        a.state.up && isready(a.state.queue) ? in_packet_processing(a,model) : nothing #println("queue of $(a.id) is empty")
        #     _ => continue
        # end
     end
     for a in allagents(model)
        pending_pkt_handler(a,model)
        @match a begin
            a::SimNE, if model.ticks%model.freq == 0 && size(a.state.in_pkt_trj,1) >= (model.freq - 1) end =>
                        # @show model.ticks, a.state.in_pkt_trj
                        push!(a.statistics, create_statistic(a,model))
            _ => nothing
        end
     end

     
     drop_node(model)
    # for a in allagents(model)
    #     #process_pulses(a,model)
    # end
end

"""
    Progress control agents one step.
"""
function agent_step!(a::Agent,model)
    #placeholder
end

"""
    Progress SimNE one step.
"""
function agent_step!(a::SimNE,model)
    #placeholder
end

"""
Simple run model function
"""
function run_model(n,args,properties; agent_data, model_data)
    model = initialize(args,properties;seed=123)

    
    # agent_shape(a::Agent) = :square
    agent_size(a) = 7
    # agent_size(a::Agent) = 7

    plot_scheduler = model.scheduler#by_type((SimNE,Agent), false)#

    plotkwargs = (
            # ac = agent_color, am = agent_shape, as = agent_size,
            # scheduler = plot_scheduler, aspect_ratio = 1
            # #Graph space properties
            # , method = :circular, node_size = 0.2
            # , 
            size = (600, 600), showaxis = false
    )

    #p = plotabm(model; plotkwargs...)
    df = init_agent_dataframe(model,agent_data)
    df_m = init_model_dataframe(model,model_data)
    anim = @animate for i in 0:n
            p = plotabm_networks(model; plotkwargs...)
            title!(p, "step $(i)")
            step!(model, agent_step!,model_step!)
            collect_agent_data!(df, model, agent_data, i)
            collect_model_data!(df_m, model, model_data, i)
        end
    println("PRINTING HERE")
    println("Space: $(model.space)")
    gif(anim, plots_dir*"animation.gif", fps = 5), df, df_m
end

function agent_color(a)
    #@show typeof(a)
    return :blue#a.color
end
        
    # agent_color(a::Agent) = :black#a.color
# function agent_shape(a)
#    #[println(c.shape) for c in a] 
   
#    return [c.shape for c in a] 
# end

function init_agents!(model)
    # for a in sort(allagents(model))
    #     init_agent(a,model)
    # end

    #force ordered start

    ids = [a.id for a in allagents(model)]
    
    for id in sort(ids)
        init_agent!(getindex(model,id),model)
    end
end

function init_agent!(a::Agent,model)
    nes = get_controlled_assets(a.id,model)
    g = model.ntw_graph
    
    a.state.paths = all_k_shortest_paths(model.ntw_graph)

    #@show a.state.paths
    #"discover" ports and links of each asset
    # for ne in nes
    #     println(find_agent(ne,model).state.port_edge_list)
    # end
    # for v in vertices(model.ntw_graph)
    #     println(" Edges of $(v) are $(all_neighbors(model.ntw_graph,v))")
    #     #println(" Edges: $(e)")
    # end
end


function init_agent!(a::SimNE,model)
    #print("Initialisation of SimNE agent $(a.id)")
    nbs = all_neighbors(model.ntw_graph,get_address(a.id,model))
    push!(a.state.port_edge_list,(0,"h$(a.id)")) # link to a host of the same id
    for i in 1:size(nbs,1)
        push!(a.state.port_edge_list,(i,"s$(nbs[i])"))
    end

    init_switch(a,model)
end

function all_k_shortest_paths(g::AbstractGraph)
    return [ (first(i.paths...),last(i.paths...),i.paths...) 
        for i in 
            filter( x -> !isnothing(x), 
                    [ s != d ? 
                        #returns YenState with distances of each path
                        yen_k_shortest_paths(g,s,d) : nothing 
                        for s in vertices(g), d in vertices(g) ]
                ) ]
end

"""
msg: SimNE.id, in_port, DPacket
"""
function in_packet_handler(a::Agent,msg::OFMessage,model)

    println("[$(model.ticks)]($(a.id)) msg-> $(msg)")
    dst = msg.data.dst
    src = msg.data.src
    path = []

    if msg.dpid != dst
        paths = filter(p-> p[1] == src && p[2] == dst ,a.state.paths)
        path = !isempty(paths) ? paths[1] : []
    end
    
    install_flow(msg.dpid,msg.in_port,path,model)
end

# function install_flows(a::SimNE,paths,model)
#     (2, 1, [2, 10, 1])


# end

function install_flow(in_dpid,in_port_start,path,model)
    println("install flow: $(in_dpid) - $(in_port_start) - $(path)")
    if !isempty(path)
        pairs = diag([j == i + 1 ? (path[3][i],path[3][j]) : nothing for i=1:size(path[3],1)-1, j=2:size(path[3],1)])
        
        prev_sne_id = path[1]
        for p in pairs
            sne = getindex(model,p[1])
            prev_sne = getindex(model,prev_sne_id)
    #        in_port = filter(x->x[2]=="s$(p[2])",sne.state.port_edge_list)[1][1]
            port_dst = filter(x->x[2]=="s$(p[2])",sne.state.port_edge_list)[1]
            out_port = port_dst[1]
            # dst = getindex(model,parse(Int64,port_dst[2][2]))
            # puertos = filter(x->x[2]=="s$(p[1])",dst.state.port_edge_list)
            # println("Puertos $(puertos) in $(dst.id)")
            # puerto = puertos[1][1]
            in_port = p[1] == path[1] ? in_port_start : filter(x->x[2]=="s$(prev_sne_id)",sne.state.port_edge_list)[1][1]
            r_src = path[1]
            r_dst = path[2]
            
            fw = Flow(sne.id,MRule(string(in_port),string(r_src),string(r_dst)),[out_port],(ticks,pkt,sne_src,sne_dst)->forward(ticks,pkt,sne_src,sne_dst))
            println("[$(model.ticks)] {A} Installing flow: $(p[1]) - $(fw.match_rule)")
            push!(sne.state.flow_table,fw)
            prev_sne_id = sne.id
        end
    else
        sne = getindex(model,in_dpid)
        #TODO how to make the rule to be regardless of port in
        fw =Flow(in_dpid,MRule("*","*",string(in_dpid)),[0],(ticks,pkt,src_sne)->forward(ticks,pkt,src_sne))
        println("[$(model.ticks)]  {B} Installing flow to $(in_dpid): $(fw.match_rule)")
        push!(sne.state.flow_table,fw)
    end
#TODO: take every pair of vertices in the path and install install_flows
   # push!(a.state.flow_table,Flow(a.id,MRule(in_port,path[1],path[2]),(pkt)->forward(pkt,out_port)))
end

function create_pkt(src::Int64,dst::Int64,model)
    model.pkt_id += 1
    return DPacket(model.pkt_id,src,dst,1500,model.:ticks,100)
end

function generate_traffic(model)

    q_pkts = abs(round(10rand(Normal(1,0.1))))
    #q_pkts = 100
    #src,dst = samplepair(1:nv(model.ntw_graph)) # can be replaced for random pair
    src,dst = (1,7)
    for i =1:q_pkts
        pkt = create_pkt(src,dst,model)
        sne = getindex(model,src)
        put!(sne.state.queue,OFMessage(model.ticks,src,0,pkt)) # always from port 0
        #put!(sne.state.queue,(model.ticks,src,0,pkt)) # always from port 0
    end

   # println("[$(model.ticks)] $(q_pkts) pkts generated")
end

function create_statistic(a::SimNE,model)
    t₋₁ = (model.ticks - model.freq + 1)
    t₀ = model.ticks
    b₋₁ = length(a.state.in_pkt_trj)- model.freq-1 > 0 ? sum(a.state.in_pkt_trj[1:(end-model.freq-1)]) * model.pkt_size : first(a.state.in_pkt_trj) * model.pkt_size
    b₀ = sum(a.state.in_pkt_trj[1:end]) * model.pkt_size

    return NEStatistics(
                     model.ticks,a.id
                    ,throughput(b₋₁,b₀,t₋₁,t₀)
                    ,0.0)
end 
