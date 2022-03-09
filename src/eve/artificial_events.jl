"""
return the times when random assets will fail
according to total sim time (N), quantity (q) of
assets and proportion. It receives also random 
"""
function get_dropping_times(seed,stabilisation_period,drop_proportion,q,N)
    Random.seed!(seed)
    #events 
    k = Int(round(q * drop_proportion))
    # k = 30
    
    time_btwn_events = Int.(ceil.(first([ rand(Exponential(1/k),k) .* (N - (2 * stabilisation_period)* 1.7)]))) # Normalise time-btwn-events over the 1.7 of the observation period (assuming that we substract stabilisation at the beginning and at the end) to make sure it falls within the simulation time.

    # @show time_btwn_events
    event_times =  stabilisation_period .+ cumsum(time_btwn_events[1:k])
    
    #For testing
    #event_times = [30,50]#,70]

    log_info("Dropping times are: $event_times")
    return event_times
end

"""
Triggers random failures on active nodes. This function is coupled to the model as it detects nodes that are active and make sure disruption happen to some of those nodes. If decoupled, cleaner, but then requires to know in advance what paths are used at every time, to make sure that dropping nodes are always active. 
"""
function trigger_random_node_drops!(model::ABM)
    #-1 pick node to remove
    #0 on_switch event
    #1remove from network
    #2in controller: update topology and paths
    #in switch detect path/port not available and ask controller
    
    if model.ticks in model.dropping_times
        #get ids of nodes that are part of active flows
        active_ids =  unique(vcat([ af[3]==f_S ? [af[2]] : af[3]==f_E ? [af[1]] : [af[1],af[2]] for af in get_state(model).active_flows if af[3]!=f_SE ]...)) 

        #ensure there is no replacement when selecting random node to drop
        active_always_up = setdiff(active_ids,unique([ last(pair) for pair in model.dropped_nodes]))

        #pick one random node
        dpn_id = !isempty(active_always_up) ? rand(active_always_up) : rand(get_live_snes(model))

        #for testing only
        # dpns_test = [5,9]#[3,10,13]
        # dpn_id = rand([ sid for sid in dpns_test if get_state(getindex(model,sid)).up  ])

        log_info(model.ticks,"Removing ntw node: $dpn_id...")
        dpn_ag = getindex(model,dpn_id)
        drop_node!(dpn_ag,model)
        

        dpn_ctl_ag = getindex(model,abs(get_control_agent(dpn_id,model)))
        schedule_event!(dpn_ctl_ag,CTL_Event(2),model.ticks+1,[dpn_id])
        schedule_event!(dpn_ctl_ag,CTL_Event(1),model.ticks+1,[-1*dpn_id])


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