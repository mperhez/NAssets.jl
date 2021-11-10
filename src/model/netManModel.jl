"""
Basic initialization
"""
function initialize(user_props;grid_dims=(3,3),seed=0)
    # pulses = []
    # for i in 1:args[:q]
    #     push!(pulses,[])
    # end

    # Global model props
    default_props = Dict(
        :ticks => 0,# # time unit
        :pkt_id => 0,
        :amsg_id =>0,
        :ofmsg_id=>0,
        :mapping_ctl_ntw => Dict{Int64,Int64}(), # mapping between (Ctl) Agent and SimNE
        :mapping_ntw_sne => Dict{Int64,Int64}(), #mapping btwn the underlying network and the corresponding simNE agent 
        :ntw_links_msgs=>Dict{Tuple{Int,Int},Vector{Vector{OFMessage}}}(),
        :ntw_links_delays =>Dict{Tuple{Int,Int},Int}(),
        :state_trj => Vector{ModelState}(),
        :base_ntw_graph => user_props[:ntw_graph],
        :dropped_nodes => Vector{Tuple{Int,Int}}()
    )
    #For G6: 
    #prob_eq_queries_cycle: 0.2
    #clear_cache_graph_freq: 30 or 15
    #query_cycle: 20 or 10
    # requires redundancy of queries + longer time graph cache (> query cycle)
    #For G7/G4: 
    #prob_eq_queries_cycle: 0.82
    #clear_cache_graph_freq: 10
    #query_cycle: 10

    Random.seed!(seed)
    props = merge(default_props,user_props)
    #space = GridSpace(grid_dims, moore=true)
    space = GraphSpace(props[:ntw_graph])
    agent_types = Union{SimNE,Agent}
    model = ABM(agent_types, space; 
    scheduler = Schedulers.randomly #random_activation
    , properties = props)
    init_model!(model)
    #create 
    create_agents!(model)
    model
end

"""
    Create simulated asset agents
"""
function create_sim_asset_agents!(model)
    a_params = Dict(:pkt_per_tick=>model.pkt_per_tick)    
    # create SimNE
    for i in 1:nv(model.properties[:ntw_graph])
        #next_fire = rand(0:0.2:model.:Τ)
        id = nextid(model)
        # @show i
        
        mnt = @match model.mnt_policy begin
            1 => MaintenanceInfoPreventive(model.deterioration,model)
            2 => MaintenanceInfoPredictive(model.deterioration,model)
            _ => MaintenanceInfoCorrective(model.deterioration,model)
        end
        # if id == 9
        #     mnt.deterioration_parameter = 2. 
        # end
        # if id in scenario_2_ids
        #     mnt.deterioration_parameter = 1. 
        # end

        a = add_agent_pos!(
                SimNE(id,i,a_params,10*model.pkt_per_tick,mnt),model
            )
        
        set_prop!(model.ntw_graph, id, :eid, id )
        # create initial mapping btwn network and SimNE
        model.mapping_ntw_sne[i] = i   
    end

    set_indexing_prop!(model.ntw_graph, :eid)
end

"""
    Create control agents
"""
function create_control_agents!(model::ABM)
    
    a_params::Dict{Symbol,Any} = Dict(:pkt_per_tick=>model.pkt_per_tick)
    mnt::MaintenanceInfo = @match model.mnt_policy begin
                1 => MaintenanceInfoPreventive(model)
                2 => MaintenanceInfoPredictive(model)
                _ => MaintenanceInfoCorrective(model)
            end
    
    if model.ctrl_model == CENTRALISED
        id = nextid(model)
        a = add_agent_pos!(
                Agent(id,1,mnt,Array{Float64}(undef,0,nv(model.properties[:ntw_graph])),a_params),model
            )
        #set_props!(model.ctl_graph, 1, Dict(:eid => 1, :aid => id) )
         ##assign controller to SimNE
        for j in 1:nv(model.properties[:ntw_graph])
            set_control_agent!(j,id,model)
        end
    else
        # log_info(" Nodes CTL: $(nv(model.properties[:ctl_graph]))")
        for i in 1:nv(model.properties[:ctl_graph])
            id = nextid(model)
            a = add_agent_pos!(
                    Agent(id,i,mnt,Array{Int64}(undef,0,1),a_params),model
                )
            set_props!(model.ctl_graph, i, Dict(:eid => i, :aid => id) )
            ##assign controller to SimNE
            #one-to-one mapping 
            set_control_agent!(i,id,model)
        end
        set_indexing_prop!(model.ctl_graph, :aid)
    end
    
    
    
end

"""
Simplest create agents
"""
function create_agents!(model)
    create_sim_asset_agents!(model)
    
    create_control_agents!(model)

    log_info("Total agents created: $(length(allagents(model)))")

    init_agents!(model)
end

"""
    It advance model one step. Agents are progressed here to ensure that one action is perform in
    all agents before the next action is performed in all agents, instead of having one action
    executed in some agents and then some start with second action.
"""
function model_step!(model)
    init_step_state!(model)
    # log_info(model.ticks,"==========")
    log_info(".")
    for a in allagents(model)
        init_state!(a)
        # if typeof(a) == SimNE 
        #     log_info("($(a.id)) ==> $(a.queue)")
        # end
    end
    generate_traffic!(model) 
    for e in edges(model.ntw_graph)
        ntw_link_step!((e.src,e.dst),model)
    end
    ctl_links_step!(model)

    # Run controllers first
    for a in allagents(model) 
        if typeof(a) == Agent
            # log_info(model.ticks,a.id,"---------")
            # log_info(model.ticks,a.id,"links: $(a.msgs_links)")
            # log_info(model.ticks,a.id," known graph: $(collect(edges(a.ntw_graph)))")
            kn = [ a.ntw_graph[i,:eid] for i=1:nv(a.ntw_graph) ]
            # log_info(model.ticks,a.id," known nodes: $(kn)")
            #log_info(model.ticks,a.id,"ctl_paths: $(a.ctl_paths)")
            do_agent_step!(a,model)
        end
    end
    #Then run SimNEs
    for a in allagents(model) 
        if typeof(a) == SimNE
            #log_info(model.ticks,a.id,"---------")
            do_agent_step!(a,model)
        end
    end
    for a in allagents(model)
        pending_pkt_handler(a,model)
        clear_cache!(a,model)
        calculate_metrics_step!(a,model)
    end
    trigger_random_node_drops!(model)
    #log_info(model.ticks,"aflows: $(get_state(model).active_flows)")
    # log_info(model.ticks,": $()")
    
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
function run_model(n,properties; agent_data, model_data)
    seed = properties[:seed]
    model = initialize(properties;seed)

    
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

   
        if model.animation 

        anim = @animate for i in 0:n
                p = plotabm_networks(model; plotkwargs...)
                title!(p, "step $(i)",position=(10,1))
                #annotate!((1,1,Plots.text("step $(i)", 11, :black, :center)))
                step!(model, agent_step!,model_step!)
                collect_agent_data!(df, model, agent_data, i)
                collect_model_data!(df_m, model, model_data, i)
            end
        plot_label = model.run_label * "_anim"
        check_create_dir!(model.plots_dir)
        gif(anim, model.plots_dir * plot_label * ".gif", fps = 5)
    else
        for i in 0:n
            step!(model, agent_step!,model_step!)
            collect_agent_data!(df, model, agent_data, i)
            collect_model_data!(df_m, model, model_data, i)
        end
    end
    df, df_m 
end

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

"""
Initialise control agents
"""
function init_agent!(a::Agent,model)

    # log_info("Starting Agent $(a.id)")
    
    if model.ctrl_model != GraphModel(1)
        #Calculate sub graphs and init msg channels among agents
        nodes = [get_controlled_assets(a.id,model)...]
        sub_g = get_subgraph(model.ntw_graph,nodes,:eid)
        # log_info("Asset Network size $(nv(sub_g))")
        nodes = [a.id]
        ctl_sub_g = get_subgraph(model.ctl_graph,nodes,:aid)       
        a.ntw_graph = sub_g
        a.base_ntw_graph = sub_g
        a.ctl_graph = ctl_sub_g
        a.params[:delay_ctl_link] = 2 # 1: no delay
        #Init vector of msgs
        a.msgs_links = init_array_vectors(AGMessage,a.params[:delay_ctl_link],degree(a.ctl_graph,to_local_vertex(a.ctl_graph,a.id,:aid)))
    else
        a.ntw_graph = model.ntw_graph
        a.base_ntw_graph = model.ntw_graph
    end

    ##
    if a.maintenance.policy !=  CorrectiveM
        schedule_event!(a,CTL_Event(4),a.maintenance.predictive_freq,Array{Int64,1}())
        if a.maintenance.policy ==  PredictiveM
            #conversion to py
            ajm_py = np.matrix(adjacency_matrix(a.ntw_graph))
            log_info(model.ticks,"adj=> $ajm_py")
            opt_init.optimisation_initialisation( ajm_py,
            model.traffic_dist_params
            #[1,0.05]
            , model.mnt_bc_cost, model.mnt_bc_duration, model.mnt_wc_cost, model.mnt_wc_duration)

            log_info(model.ticks,"H2=> $(opt_init.H2)")
        end
    end
end

function label_paths(time::Int64,paths::Array{LightGraphs.YenState{Float64,Int64},1})
    npaths = Dict()
    if !isempty(paths)
        for path in paths 
            if !isempty(path.paths)
                #obtain only the first path
                npaths[(first(first(path.paths)),last(first(path.paths)))] = [(time,first(path.dists),first(path.paths))]
            end
        end
    end
    return npaths
end


function label_path(path)
    
    return (first(path),last(path),path)
end

"""
Initialise sne agents
"""
function init_agent!(sne::SimNE,model)
    #print("Initialisation of SimNE agent $(a.id)")
    nbs = all_neighbors(model.ntw_graph,get_address(sne.id,model.ntw_graph))
    
    push_ep_entry!(sne,(0,"h$(sne.id)")) # link to a host of the same id
    
    for i in 1:size(nbs,1)
        push_ep_entry!(sne,(i,"s$(nbs[i])"))
        #install flows to host of the same id
        # install_flow!(Flow(sne.id,MRule("$i","$(nbs[i])","$(sne.id)"),[0],OFS_Action(1)),sne,model)
    end

    init_condition!(sne,model)
    init_maintenance!(sne,model)
end

"""
    Next agent message's id
"""
function next_amid!(model)
    model.amsg_id += 1
    return model.amsg_id
end

"""
    Next Open Flow message id
"""
function next_ofmid!(model)
    model.ofmsg_id += 1
    return model.ofmsg_id
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

function set_active_flows(m::ABM,af::Vector{Tuple{Int,Int,Flow_Type}})
    current = pop!(m.state_trj)
    current.active_flows = af
    push!(m.state_trj,current_logger)
end

function set_state!(m::ABM,new_state::ModelState)
    pop!(m.state_trj)
    push!(m.state_trj,new_state)
end

function init_model!(m::ABM)
    #all delays equal initially
    for e in edges(m.ntw_graph)
        #log_info("[$(m.ticks)] edge: $((e.src,e.dst))")
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
        to_deliver = first(msgs)
        in_pkt_count = 0

        # if model.ticks >= 65 && model.ticks <= 86
        #      log_info(model.ticks," link ($(l)) -> $(msgs)")
        # end

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
                if length(dst.queue.data) < dst.queue.sz_max
                    
                    put!(dst.queue,msg)
                    in_pkt_count = get_state(dst).in_pkt + 1
                    set_in_pkt!(dst,in_pkt_count)
                else
                    s = get_state(dst)
                    s.drop_pkt += 1
                    set_state!(dst,s)
                end
            end
        end
    end
    
end

"""
    Initialize an array of dimensions d1 x d2 that contains vectors of type T
"""
function init_array_vectors(T,d1,d2)
    arr = d2 >= 1 ? Array{Vector{T}}(undef,d1,d2) : Array{Vector{T}}(undef,d1)
    [ arr[i,j] = Vector{T}() for i=1:size(arr,1) for j=1:size(arr,2)]
    return arr
end

function ctl_links_step!(model)
    if model.ctrl_model != GraphModel(1)
        ctl_ags = filter(a->typeof(a) == Agent,Set(allagents(model)))
        #log_info(ctl_ags)
        ctl_link_step!.(ctl_ags)
    end

end

function ctl_link_step!(a::Agent)
    #log_info("=== START Processing links of Ag: $(a.id) => $(a.msgs_links) -- $(a.msgs_in) ===")
    #Merge msgs from all senders to be processed
    a.msgs_in = vcat(a.msgs_links[1,:]...)
    a.msgs_links[1,:] = init_array_vectors(AGMessage,size(a.msgs_links,2),1)
    a.msgs_links = circshift(a.msgs_links,1)
    #log_info("=== END Processing links of Ag: $(a.id) => $(a.msgs_links) -- $(a.msgs_in) ===")
end
    
function get_state_trj(m::ABM)::Vector{ModelState}
    return m.state_trj
end

"""
Return total of control messages exchanged by agents
"""
function get_ag_msg(model)
    #log_info([ [ s.in_ag_msg for s in a.state_trj ] for a in allagents(model) if typeof(a) == Agent ])
    return cumsum(sum.(eachcol([ [ s.in_ag_msg for s in a.state_trj ] for a in allagents(model) if typeof(a) == Agent ]))...)    
end

function is_active_flow(f::Tuple{Int,Int},model)
    v = !isempty(filter(af->(af[1],af[2]) == f || (af[2],af[1]) == f  ,get_state(model).active_flows))
    # log_info(model.ticks,"$f ==> $v")
    return v
end