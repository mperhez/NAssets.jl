"""
Triggers random failures on active nodes
"""
function trigger_random_node_drops!(model)
    #-1 pick node to remove
    #0 on_switch event
    #1remove from network
    #2in controller: update topology and paths
    #in switch detect path/port not available and ask controller
    
    if model.ticks in model.dropping_times
        #get ids of nodes that are part of active flows
        active_ids =  unique(vcat([ af[3]==f_S ? [af[2]] : af[3]==f_E ? [af[1]] : [af[1],af[2]] for af in get_state(model).active_flows if af[3]!=f_SE ]...)) 

        #pick one random node
        dpn_id = !isempty(active_ids) ? rand(active_ids) : rand(get_live_snes(model))

        #for testing only
        dpns_test = [5,9]#[3,10,13]
        dpn_id = rand([ sid for sid in dpns_test if get_state(getindex(model,sid)).up  ])

        log_info(model.ticks,"Removing ntw node: $dpn_id...")
        dpn_ag = getindex(model,dpn_id)
        drop_node!(dpn_ag,model)        
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