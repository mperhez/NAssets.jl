"""
Find agent in the model given the id
"""
function find_agent(id,model)
    first(filter(a->a.id == id,Set(allagents(model))))
end

function get_control_agent(asset_id::Int,model)
    return model.mapping_ctl_ntw[asset_id]
end

function get_controlled_assets(agent_id::Int,model)::Set{Int64}
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
    # log_info(model.ticks,a.id, "start step! $(get_state(a).up) ==> $(get_state(a).rul)")
    
    is_up(a) && is_ready(a) ? in_packet_processing(a,model) : nothing 
    clear_pending_query!(a,model)
   
    deteriorate!(a,model)
end

function do_agent_step!(a::Agent,model)
    #Schedule events regardless of state of ctl agent to make sure that controlled snes are brought back up 
    #This is the first function to make sure that nodes that are down are recognised by others.
    do_events_step!(a,model)
    if is_up(a) && (length(a.msgs_in)> 0 || length(a.queue.data) > 0)
        # for sprt in sne_print
        #     log_info(model.ticks,a.id," step!: {$(sprt.id)} $(get_state(sprt).flow_table) ===> all ports: $(get_port_edge_list(sprt)) ===> paths: $(a.paths)")
        # end        

        ## Process OF Messages (SimNE to (sdn) control messages)
        if is_ready(a) 
             in_packet_processing(a,model)
        end
        # Process inter-agent messages
        # log_info(model.ticks,a.id,"==> a.paths ==> $(a.paths) ===> $(a.msgs_in) <==")
        do_receive_messages(a,model)
        
        # log_info(model.ticks,a.id,"ctl_agent step: $(neighbors(a.ntw_graph,4))")
    end
    # log_info(model.ticks,a.id,25,"pending msgs: $(length(a.
    # pending)) --> $(a.pending)")
    # log_info(model.ticks,a.id,25,"QUEUE --> $(a.queue.data)")

    # do_confidence_check!(a,model)

    # if !isempty(get_state(a).active_paths)
    #     log_info(model.ticks,a.id,"ap-->$(get_state(a).active_paths)")
    # end

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

"""
Records benchmark for a query
"""
function record_benchmark!(bdir,run_label,aid,query_time,query,query_graph,query_paths,benchmark)
    if benchmark 
        if !isdir(bdir)
        mkdir(bdir) 
        end
        #benchmark block start
        b = @benchmark begin 
            do_query($query_time,$query,$query_graph,$query_paths)
        end
        serialize( bdir * "/"* run_label *"_$(first(query))_$(last(query))_$(query_time)_$(aid)_bchmk.bin",b)
    end        
end

## main functions

new_config(seed,ctl_model,ntw_topo,size,n_steps,drop_proportion,prob_random_walks,benchmark, animation,k,B,ctl_k,ctl_B,mnt_policy,ntw_services,mnt_wc_duration,mnt_bc_duration,mnt_wc_cost,mnt_bc_cost,traffic_dist_params,traffic_proportion,clear_cache_graph_freq,interval_tpt,pkt_size,pkt_per_tick,max_queue_ne,ofmsg_reattempt, max_cache_paths) =
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
            ,B = B
            ,ctl_k=ctl_k
            ,ctl_B = ctl_B
            ,custom_topo = nothing
            ,ctl_custom_topo = nothing
            ,mnt_policy = mnt_policy
            ,ntw_services = ntw_services
            ,mnt_wc_duration = mnt_wc_duration
            ,mnt_bc_duration = mnt_bc_duration
            ,mnt_wc_cost = mnt_wc_cost
            ,mnt_bc_cost = mnt_bc_cost
            ,traffic_dist_params = traffic_dist_params
            ,traffic_packets = traffic_packets
            ,link_capacity = link_capacity
            ,clear_cache_graph_freq = clear_cache_graph_freq
            ,interval_tpt = interval_tpt
            ,pkt_size = pkt_size
            ,pkt_per_tick = pkt_per_tick
            ,max_queue_ne = max_queue_ne
            ,ofmsg_reattempt = ofmsg_reattempt
            ,max_cache_paths = max_cache_paths
            )

function get_dropping_nodes(drop_proportion)
    #TODO calcualte according to proportion
    return Dict(
       50 => [3]
        #55: Grid and Grid fails
        , 75 => [8]
        #, 115 => [11]
        # , 70 => [10]
        #50=>[3,6] #TODO simoultaneous drops only work in centralised control
    #,120=>[2]
    ) # drop time => drop node
end

"""
It returns the next event time for a given random number and rate of events
"""
function next_event_time(rn,λ)
    return -log(1.0-rn)/λ
end

"""
Clears cache of control agent
# TODO Opportunity to investigate ways to store relevant cache rather than clearing all
"""
function clear_cache!(a::Agent,model::ABM)
    if model.ticks - a.last_cache_cleared == model.clear_cache_graph_freq
        a.ntw_graph = a.base_ntw_graph
        a.last_cache_cleared = model.ticks
        a.previous_queries = Dict()
        a.paths = Dict()
    end

end

function clear_cache!(sne::SimNE,model::ABM)
    #placeholder
end

function to_string(s)
    sep = "; "
    return join([getfield(s,a) for a in fieldnames(typeof(s))],sep)
end

"""
Return SNEs that are up
"""
function get_live_snes(model)
    return [ sne.id for sne in allagents(model) if typeof(sne) == SimNE && get_state(sne).up  ]
end
"""
Return SNEs controlled by Agent a that are up
"""
function get_live_snes(a::Agent,model)
    controlled_snes = [ getindex(model,sid) for sid in get_controlled_assets(a.id,model)]
    return [ sne.id for sne in controlled_snes if get_state(sne).up  ]
end

# function init_logger(log_name)
#     loggers[log_name] = getlogger(log_name)
#     setlevel!(loggers[log_name], "info")
#     push!(loggers[log_name],getlogger(name="root"))
#     # push!(loggers[log_name], DefaultHandler(tempname(), DefaultFormatter("[{date} | {level} | {name}]: {msg}")))
#     return loggers[log_name]
# end