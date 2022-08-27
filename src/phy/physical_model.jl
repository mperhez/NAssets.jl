"""
Removes asset node (sne) from the network
"""
function drop_node!(sne::SimNE,model::ABM)
    set_down!(sne)
    g = model.ntw_graph
    # log_info(model.ticks," All neighbours of $(sne.id) are: $(all_neighbors(model.ntw_graph,get_address(sne.id,g))) ")
    for nb in all_neighbors(model.ntw_graph,get_address(sne.id,g))
       sne_nb = getindex(model,get_eid(nb,model))
       link_down!(sne_nb,sne.id,model)
    end
    
    #delete pending queries to control
    sne.requested_ctl = Dict()

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

    # log_info(model.ticks,sne.id,"Deteriorating from rul: $(state.rul) ")

    # deteriorates only if up and it was not repaired in this tick 
    if state.up && first(last(sne.state_trj,2)).rul >= state.rul
         state.rul = first(sne.maintenance.deterioration)(state.rul,model.ticks,last(sne.maintenance.deterioration,size(sne.maintenance.deterioration,2)-1)...)
         a = getindex(model,abs(sne.controller_id))
        
        # log_info(model.ticks,sne.id," (rul - thd) --> $(state.rul - sne.maintenance.threshold)  ===> $((state.rul - sne.maintenance.threshold ) <= 0)  ------ mnt policy $(sne.maintenance.policy) --- rul: $(state.rul)  ---- thd: $(sne.maintenance.threshold)" )

        if state.rul - model.deterioration_threshold  <= 0
            drop_node!(sne,model)
            if sne.maintenance.policy == CorrectiveM
                schedule_event!(a,CTL_Event(2),model.ticks+1,[sne.id])
                # log_info(model.ticks,a.id," scheduling corrective maintenance.. for $([sne.id]) at $(model.ticks+1) bcause rul: $(state.rul)  and thd = $(sne.maintenance.threshold)")
                schedule_event!(a,CTL_Event(1),model.ticks+1,[-1*sne.id])
            end
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
    if model.seed >= 0
        Random.seed!(model.seed)
    end
    #get_random(model.seed,1)
    # TODO check heterogenous assets with different expected rul
    state = get_state(sne)
    #randomly initialize condition of sne
    # state.rul = rand((sne.maintenance.eul-30):sne.maintenance.eul,nv(model.ntw_graph))[sne.id]
    
    # state.rul = rand(50:100,nv(model.ntw_graph))[sne.id]
    state.rul = typeof(model.init_sne_params) <: NamedTuple && sne.id in model.init_sne_params.ids &&  Symbol("ruls") in keys(model.init_sne_params) ? model.init_sne_params.ruls[first(indexin(sne.id,model.init_sne_params.ids))] : Int.(round.(rand(Uniform(50,100),nv(model.ntw_graph))))[sne.id]

    #set maitenance due time
    state.maintenance_due = model.ticks + state.rul
    set_state!(sne,state)
end

