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
        :ctrl_model => DISTRIBUTED, #CENTRALISED,
        :pkt_size => 1500,
        :freq => 30, # frequency of monitoring
        :N=>args[:N],
        # key(src,dst)=>value(time_left_at_link =>msg)
        :ntw_links_msgs=>Dict{Tuple{Int,Int},Vector{Vector{OFMessage}}}(),
        :ntw_links_delays =>Dict{Tuple{Int,Int},Int}(),
        :state_trj => Vector{ModelState}()
    )

    Random.seed!(seed)
    props = merge(default_props,user_props)
    #space = GridSpace(grid_dims, moore=true)
    space = GraphSpace(props[:ntw_graph])
    agent_types = Union{SimNE,Agent}
    model = ABM(agent_types, space; scheduler = random_activation, properties = props)
    init_model!(model)
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
        id = nextid(model)
        # @show i
        a = add_agent_pos!(
                SimNE(id,i,a_params),model
            )
        # create initial mapping btwn network and SimNE
        model.mapping_ntw_sne[i] = i   
    end

    println(" Nodes CTL: $(nv(model.properties[:ctl_graph]))")
    #create control agents 1:1
    for i in 1:nv(model.properties[:ctl_graph])
        #next_fire = rand(0:0.2:model.:Τ)
        id = nextid(model)
        a = add_agent_pos!(
                Agent(id,i,a_params),model
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
    init_step_state!(model)
    for a in allagents(model)
        init_state!(a)
    end
    
    for e in edges(model.ntw_graph)
        ntw_link_step!((e.src,e.dst),model)
    end
    if model.ticks in 80:1:90
        println("[$(model.ticks)] - AFTER Processing $(get_state(getindex(model,10)))")
    end    
    generate_traffic(model)
    #print("Has sent packet to $(sne.id)")
#    print(last(model.state_trj))

   # @show model.ticks
    for a in allagents(model)
        #init_state!(a)
    #     #pulse(a,model)
        # @match a begin
        #     a::SimNE => 
        is_up(a) && is_ready(a) ? in_packet_processing(a,model) : nothing #println("queue of $(a.id) is empty")
        #     _ => continue
        # end
     end
     for a in allagents(model)
        pending_pkt_handler(a,model)
     end


     soft_drop_node(model)
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
            size = (1000, 600),
            showaxis = false
    )

    #p = plotabm(model; plotkwargs...)
    df = init_agent_dataframe(model,agent_data)
    df_m = init_model_dataframe(model,model_data)
    anim = @animate for i in 0:n
            p = plotabm_networks(model; plotkwargs...)
            title!(p, "step $(i)",position=(10,1))
            #annotate!((1,1,Plots.text("step $(i)", 11, :black, :center)))
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

end


function init_agent!(a::SimNE,model)
    #print("Initialisation of SimNE agent $(a.id)")
    nbs = all_neighbors(model.ntw_graph,get_address(a.id,model))
    
    push_ep_entry!(a,(0,"h$(a.id)")) # link to a host of the same id
    
    for i in 1:size(nbs,1)
        push_ep_entry!(a,(i,"s$(nbs[i])"))
    end

    #initialise condition: we generate entire time series to failure
    # TODO: Review
    #simulated sensor functions
    funs = [
        (exp_f,(1.0,0.05),exp_ts,(),exp_c), 
        (weibull_f,(1.0,1.0),wb_ts,(6.0),wb_c),
        (log_f,(50,0.1),log_ts,(),log_c)
        ]
    
    ttf = 100
    Δᵩ = 0.05
    downtime = 2 #time steps
    a.condition_ts = generate_sensor_series(ttf,model.N,Δᵩ,0.05,downtime,funs)
    vrul = generate_rul_series(ttf,Δᵩ,model.N,downtime)
    a.rul = vrul#reshape(vrul,length(vrul),1)
       
    init_switch(a,model)
end

function all_k_shortest_paths(g::AbstractGraph)
    return [ !isempty(i.paths) ? (first(i.paths...),last(i.paths...),i.paths...) : (-1,-1,[])
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
            port_dst = filter(x->x[2]=="s$(p[2])",get_port_edge_list(sne))[1]
            out_port = port_dst[1]
            in_port = p[1] == path[1] ? in_port_start : filter(x->x[2]=="s$(prev_sne_id)",get_port_edge_list(sne))[1][1]
            r_src = path[1]
            r_dst = path[2]
            
            fw = Flow(sne.id,MRule(string(in_port),string(r_src),string(r_dst)),[out_port],OFS_Output)
            #(ticks,pkt,sne_src,sne_dst)->forward(ticks,pkt,sne_src,sne_dst)
            println("[$(model.ticks)] {A} Installing flow: $(p[1]) - $(fw.match_rule)")
            push_flow!(sne,fw)
            prev_sne_id = sne.id
        end
    else
        sne = getindex(model,in_dpid)
        #TODO how to make the rule to be regardless of port in
        fw =Flow(in_dpid,MRule("*","*",string(in_dpid)),[0],OFS_Output)
        #(ticks,pkt,src_sne)->forward(ticks,pkt,src_sne)
        println("[$(model.ticks)]  {B} Installing flow to $(in_dpid): $(fw.match_rule)")
        push_flow!(sne,fw)
    end
end

function create_pkt(src::Int64,dst::Int64,model)
    model.pkt_id += 1
    return DPacket(model.pkt_id,src,dst,1500,model.:ticks,100)
end

function generate_traffic(model)

    q_pkts = abs(round(10rand(Normal(1,0.1))))
    #q_pkts = 100
    #src,dst = samplepair(1:nv(model.ntw_graph)) # can be replaced for random pair
    pairs = [(1,7),(4,1),(9,5)]    
    for p in pairs
        src,dst = p
        for i =1:q_pkts
            pkt = create_pkt(src,dst,model)
            sne = getindex(model,src)
            push_msg!(sne,OFMessage(model.ticks,src,0,pkt)) # always from port 0
        end
    end

   # println("[$(model.ticks)] $(q_pkts) pkts generated")
end

"""
    Initialise state of model for a given step
"""
function init_step_state!(m::ABM)
    m.ticks += 1
    new_state = ModelState(m.ticks)#deepcopy(get_state(m))
    #for e in edges(m.ntw_graph)
    #    new_state.links_load[(e.src,e.dst)] = 0
           # read from links according to delay
   # put msgs in destination nodes for those where delay is over

        #m.ntw_links[k] 
    #end
    push!(m.state_trj,new_state)
end

function get_state(m::ABM)
    return last(m.state_trj)
end


function init_model!(m::ABM)
    #all delays equal initially
    for e in edges(m.ntw_graph)
        println("[$(m.ticks)] edge: $((e.src,e.dst))")
        m.ntw_links_delays[(e.src,e.dst)] = 1
    end

    #init link msgs
    # for e in edges(m.ntw_graph)
    #     link_queue = Vector{Vector{OFMessage}}()
    #     for q=1:m.ntw_links_delays[(e.src,e.dst)]
    #         push!(link_queue,Vector{OFMessage}())
    #     end
    #     m.ntw_links_msgs[(e.src,e.dst)] = link_queue
    # end

end

function init_link_msg!(l::Tuple{Int,Int},m::ABM)
    link_queue = Vector{Vector{OFMessage}}()
    for q=1:m.ntw_links_delays[l]
        push!(link_queue,Vector{OFMessage}())
    end
    m.ntw_links_msgs[l] = link_queue
end


function ntw_link_step!(l::Tuple{Int,Int},model)
    if haskey(model.ntw_links_msgs,l)
        msgs = model.ntw_links_msgs[l]
        if model.ticks in 80:1:90 
            println("[$(model.ticks)] - $(l) -> msgs: $(length(first(msgs)))")
        end
        to_deliver = first(msgs)
        in_pkt_count = 0
        if !isempty(to_deliver)
            if length(msgs) > 1
                msgs = msgs[begin+1:end]
                push!(msgs,Vector{OFMessage}())
            else
                msgs = [ Vector{OFMessage}() ]
            end
            
            model.ntw_links_msgs[l] = msgs

            for msg in to_deliver
                #Does it need to check address?, I don't think so
                dst = msg.dpid == l[1] ? getindex(model,l[2]) : getindex(model,l[1])
                put!(dst.queue,msg)
                in_pkt_count = get_state(dst).in_pkt + 1
                set_in_pkt!(dst,in_pkt_count)
            end
            #push!(model.state_trj,ModelState(model.ticks))
        end
    end
end
    
function get_state_trj(m::ABM)::Vector{ModelState}
    return m.state_trj
end
