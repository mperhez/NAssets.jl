"""
Removes asset node (sne) from the network
"""
function drop_node!(sne::SimNE,model::ABM)
    set_down!(sne)
    g = model.ntw_graph
    log_info(model.ticks," All neighbours of $(sne.id) are: $(all_neighbors(model.ntw_graph,get_address(sne.id,g))) ")
    for nb in all_neighbors(model.ntw_graph,get_address(sne.id,g))
       sne_nb = getindex(model,get_eid(nb,model))
       link_down!(sne_nb,sne.id,model)
    end
       
    #it simulates control detects sne down:
    aid = get_control_agent(sne.id,model)
    a = getindex(model,abs(aid))
    controlled_sne_down!(a,sne.id,model)

    #soft remove 
    model.ntw_graph = soft_remove_vertex(g,get_address(sne.id,g))
    push!(model.dropped_nodes,(model.ticks,sne.id))
end

"""
   Function to deteriorate a network element
"""
function deteriorate!(sne::SimNE,model::ABM)
    state = get_state(sne)
    if state.up
        # if sne.id == 5
        #     state.rul = state.rul - 3
        # else
            state.rul = lineal_d(sne.maintenance.deterioration_parameter,state.rul,1)
        # end

        if state.rul == 0
            a = getindex(model,abs(sne.controller_id))
            drop_node!(sne,model)
            schedule_event!(a,CTL_Event(2),model.ticks+1,[sne.id])
            schedule_event!(a,CTL_Event(1),model.ticks+1,[-1*sne.id])
        end
    end
end

function init_condition!(sne::SimNE,model::ABM)
    #initialise condition: we generate entire time series to failure
    # TODO: Review
    #simulated sensor functions
    # funs = [
    #     (exp_f,(1.0,0.05),exp_ts,(),exp_c), 
    #     (weibull_f,(1.0,1.0),wb_ts,(6.0),wb_c),
    #     (log_f,(50,0.1),log_ts,(),log_c)
    #     ]
    
    # ttf = 100
    # Δᵩ = 0.05
    # downtime = 2 #time steps
    # sne.condition_ts = generate_sensor_series(ttf,model.N,Δᵩ,0.05,downtime,funs)
    # vrul = generate_rul_series(ttf,Δᵩ,model.N,downtime)
    # sne.rul = vrul#reshape(vrul,length(vrul),1)
    Random.seed!(model.seed)
    #get_random(model.seed,1)
    # TODO check heterogenous assets with different expected rul
    state = get_state(sne)
    #randomly initialize condition of sne
    # state.rul = rand((sne.maintenance.eul-30):sne.maintenance.eul,nv(model.ntw_graph))[sne.id]
    
    state.rul = rand(50:100,nv(model.ntw_graph))[sne.id]
    #TODO allow for different degradation profiles to be passed by user, e.g. time-dependent where the deterioration function changes at a given time-step
    # state.rul = sne.id in scenario_2_ids ? scenario_2_ruls[first(indexin(sne.id,scenario_2_ids))] : rand(50:100,nv(model.ntw_graph))[sne.id]

    #set maitenance due time
    state.maintenance_due = model.ticks + state.rul
    set_state!(sne,state)
end

