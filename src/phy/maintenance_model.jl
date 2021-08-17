"""
"""
function get_next_maintenance_due(sne::SimNE,model::ABM)
    time_maintenance = 0
    state = get_state(sne)
    #corrective
    # Do not care about maintenance due date, just wait for sne to break
    if !state.up 
        time_maintenance = model.ticks
    end

    #basic preventive

    #?? calculate next maintenance from sne.eul and started rul

    return time_maintenance
end


# function trigger_maintenance(sne::SimNE)
#     state = get_state(sne)
#     # if state.maintenance_due == model.ticks

#     # end
# end

# """
# It triggers maintenance when the asset is brokendown

# """
# function do_corrective_man(sne::SimNE)
#     state = get_state(sne)
#     if !state.up
#         trigger_maintenance(sne)
#     end
# end

# """
# It triggers maintenance on due date assuming is before the asset breakdown
# """
# function do_preventive_man(sne::SimNE,model::ABM)
#     state = get_state(sne)
#     if state.maintenance_due == model.ticks
#         trigger_maintenance(sne)
#     end
# end

function init_maintenance!(sne::SimNE,model::ABM)
    state = get_state(sne)
    #init with according to factory estimated parameters
    state.rul_e = state.rul
    state.maintenance_due = state.rul_e - sne.maintenance.threshold
    set_state!(sne,state)
end


function start_mnt!(sne::SimNE,time_start::Int64,mnt_policy::Type{CorrectiveM})
    log_info(time_start,sne.id,"Starting corrective maintenance...")
    
    sne.maintenance.job_start = time_start
    state = get_state(sne)
    state.up = false
    state.on_maintenance = true
    set_state!(sne,state)


end

function start_mnt!(sne::SimNE,time_start::Int64,mnt_policy::Type{PreventiveM})
    log_info(time_start,sne.id,"Starting preventive maintenance..")
end

function stop_mnt!(sne::SimNE,mnt_policy::Type{CorrectiveM},model::ABM)
    log_info(model.ticks,sne.id,"Stopping corrective maintenance for $(nv(model.ntw_graph))...")
    rejoin_node!(model,sne.id)
    state = get_state(sne)
    state.on_maintenance = false
    state.rul = sne.maintenance.eul
    state.maintenance_due = sne.maintenance.job_start + sne.maintenance.duration + sne.maintenance.eul - sne.maintenance.threshold
    sne.maintenance.job_start = -1
    set_state!(sne,state)
    log_info(model.ticks,sne.id,"Stopped maintenance for $(nv(model.ntw_graph))...")
end

function stop_mnt!(sne::SimNE,mnt_policy::Type{PreventiveM},model::ABM)
    log_info(model.ticks,sne.id,"Stopping preventive maintenance..") 
end


function get_rul_predictions(sne::SimNE,current_time::Int64,window_size::Int64)::Vector{Int64}
    rul = get_state(sne).rul
    return [ Int(lineal_d(sne.maintenance.deterioration_parameter,rul,t)) for t = 1 : window_size  ]
end

"""
Do corrective maintenance activities for the assets under control of a given agent.
"""
function do_maintenance_step!(a::Agent,mnt_policy::Type{CorrectiveM},model::ABM)
   
    sne_ids = get_controlled_assets(a.id,model)

    for sne_id in sne_ids
        sne = getindex(model,sne_id)
        if is_start_mnt(sne,mnt_policy,model)
            start_mnt!(sne,model.ticks,mnt_policy)
        end
        if sne.maintenance.job_start > 0 && sne.maintenance.job_start + sne.maintenance.duration == model.ticks
            stop_mnt!(sne,mnt_policy,model)
        end
    end

end


function update_maintenance_plan!(a,type{PreventiveM},model)
    window_size = a.maintenance.prediction_window
    ruls = a.rul_predictions[:,size(a.rul_predictions,2)-window_size+1:size(a.rul_predictions,2)]
    #mnt_plan = 
    for i=1:size(ruls,1)
        min_rul = findall(x->x==1,ruls[i,:] .> a.maintenance.threshold)

        if !isempty(min_rul)
            push!(a.maintenance.pending_jobs,(minimum(min_rul),i))
        end
    end
end

function update_maintenance_plan!(a,type{PredictiveM},model)
    window_size = a.maintenance.prediction_window
    ruls = a.rul_predictions[:,size(a.rul_predictions,2)-window_size+1:size(a.rul_predictions,2)]
    #pycall to optimisation function
    mnt_plan = opt_run.maintenance_planning(model.ntw_services, ruls)
    push!(a.maintenance.pending_jobs,[ mnt_plan[i] != 0 : (model.ticks+mnt_plan[i],i) for i in 1:length(mnt_plan)]...)

end

"""
Do preventive maintenance activities for the assets controlled by the given agent.
"""
function do_maintenance_step!(a::Agent,mnt_policy::Type{PreventiveM},model::ABM)

    #prediction
    if model.ticks%a.maintenance.predictive_freq == 0
        window_size = a.maintenance.prediction_window
        #sort snes by id, works either for centralised (all assets one control agent or decentralised 1 asset per agent) #TODO decentralised with more than 1 asset per agent.
        sne_ids = sort(collect(get_controlled_assets(a.id,model)))
        snes = getindex.([model],sne_ids)
        
        #arrange predictions in a matrix of dims: length(snes) x window_size.
        ruls_pred = permutedims(hcat(get_rul_predictions.(snes,[model.ticks],[window_size])...))
        a.rul_predictions = length(a.rul_predictions) > 0 ? hcat(a.rul_predictions,ruls_pred) : ruls_pred
        # log_info(model.ticks,a.id," length: $(size(a.rul_predictions)) rul pred: $(a.rul_predictions)")
        log_info(model.ticks,a.id,"Pred Maint=> services: $(model.ntw_services))")

        update_maintenance_plan!(a,mnt_policy,model)
    end
    
    #check a.pending_jobs if any job for the current tick, if so start
    s.maintenance.pending_jobs

    #for start
    ##create ag message for predicted nes down

    #check duration against job start
    #for stop
    ## create message for predicted nes_down? (should be renamed)
    ## retrigger query and install of paths with maintained assets


end




function is_start_mnt(sne::SimNE,mnt_policy::Type{CorrectiveM},model::ABM)
    return !get_state(sne).up && !get_state(sne).on_maintenance
end

function is_start_mnt(sne::SimNE,mnt_policy::Type{PredictiveM},model::ABM)
    return get_state(sne).maintenance_due - sne.maintenance.threshold == model.ticks 
end

function is_start_mnt(sne::SimNE,mnt_policy::Type{PreventiveM},model::ABM)
    return get_state(sne).maintenance_due == model.ticks
end

function MaintenanceInfoCorrective(model)
    # TODO adjust to multiple eul. For time being, always 100. 
    return MaintenanceInfo(CorrectiveM,100,-1,model.mnt_wc_duration,model.mnt_wc_cost,0,0,0,0.,[],model.mnt_wc_duration,model.mnt_wc_cost)
end
function MaintenanceInfoPreventive(model)
    return MaintenanceInfo(PreventiveM,100,-1,model.mnt_bc_duration,model.mnt_bc_cost,10,10,10,1.,[],model.mnt_wc_duration,model.mnt_wc_cost)
end
function MaintenanceInfoPredictive(model)
    return MaintenanceInfo(PredictiveM,100,-1,model.mnt_bc_duration,model.mnt_bc_cost,10,10,10,1.,[],mode.mnt_wc_duration,model.mnt_wc_cost)
end

