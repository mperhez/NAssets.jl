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

function start_mnt!(sne::SimNE,time_start::Int64)
    sne.maintenance.job_start = time_start
    state = get_state(sne)
    state.up = false
    state.on_maintenance = true
    set_state!(sne,state)
end

function stop_mnt!(sne::SimNE)
    state = get_state(sne)
    state.on_maintenance = false
    state.rul = sne.maintenance.eul
    state.maintenance_due = sne.maintenance.job_start + sne.maintenance.duration + sne.maintenance.eul - sne.maintenance.threshold
    sne.maintenance.job_start = -1
    set_state!(sne,state)

end

function start_mnt!(sne::SimNE,time_start::Int64,mnt_policy::Type{CorrectiveM})
    log_info(time_start,sne.id,"Starting corrective maintenance...")
    
    start_mnt!(sne,time_start)


end

function start_mnt!(sne::SimNE,time_start::Int64,mnt_policy::Type{PreventiveM})
    log_info(time_start,sne.id,"Starting preventive maintenance..")
end

function stop_mnt!(sne::SimNE,mnt_policy::Type{CorrectiveM},model::ABM)
    log_info(model.ticks,sne.id,"Stopping corrective maintenance for $(nv(model.ntw_graph))...")
    rejoin_node!(model,sne.id)
    stop_mnt!(sne)
    log_info(model.ticks,sne.id,"Stopped maintenance for $(nv(model.ntw_graph))...")
end

function stop_mnt!(sne::SimNE,mnt_policy::Type{PreventiveM},model::ABM)
    log_info(model.ticks,sne.id,"Stopping preventive maintenance..") 
end


function get_rul_predictions(sne::SimNE,current_time::Int64,window_size::Int64)::Vector{Float64}
    rul = get_state(sne).rul
    return [ lineal_d(sne.maintenance.deterioration_parameter,rul,t) for t = 1 : window_size  ]
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

function schedule_maintenance!(a::Agent,mnt_due::Int64,sne_id::Int64)
    #sne.id => i, time => mnt_due
            #schedule start and stop of maintenance job
            if !haskey(a.maintenance.pending_jobs_start,mnt_due)
                a.maintenance.pending_jobs_start[mnt_due] = []
            end
            if !haskey(a.maintenance.pending_jobs_stop,mnt_due+a.maintenance.duration+1)
                a.maintenance.pending_jobs_stop[mnt_due+a.maintenance.duration+1] = []
            end
            push!(a.maintenance.pending_jobs_start[mnt_due],sne_id)
            push!(a.maintenance.pending_jobs_stop[mnt_due+a.maintenance.duration+1],sne_id)
end

function update_maintenance_plan!(a::Agent,mnt_policy::Type{PreventiveM},model::ABM)
    window_size = a.maintenance.prediction_window
    ruls = a.rul_predictions[:,size(a.rul_predictions,2)-window_size+1:size(a.rul_predictions,2)]
    #mnt_plan = 
    for i=1:size(ruls,1)
        threshold_reached = findall(x->x==1,ruls[i,:] .<= a.maintenance.threshold)
        if !isempty(threshold_reached)
            schedule_maintenance!(a,model.ticks + minimum(threshold_reached),i)
        end
    end
end

function update_maintenance_plan!(a::Agent,mnt_policy::Type{PredictiveM},model::ABM)
    window_size = a.maintenance.prediction_window
    ruls = a.rul_predictions[:,size(a.rul_predictions,2)-window_size+1:size(a.rul_predictions,2)]
    #data conversion to py
    services_py = np.matrix(model.ntw_services)
    ruls_py = np.matrix(ruls)
    #pycall to optimisation function
    log_info(model.ticks,a.id,"srvs=>$(services_py)")
    log_info(model.ticks,a.id,"ruls_py=>$(ruls_py)")
    mnt_plan = opt_run.maintenance_planning(services_py, ruls_py)
    log_info(model.ticks,a.id," From Alena's algo: $(mnt_plan)")
    for sne_id in 1:length(mnt_plan) 
        if mnt_plan[sne_id] > 0
            schedule_maintenance!(a,model.ticks+mnt_plan[sne_id],sne_id)
        end
    end
end

"""
It processes scheduled events
"""
function do_events_step!(a::Agent,model::ABM)
    if haskey(a.events,model.ticks)
        evs = a.events[model.ticks]
        ntw_changes = []

        for e in evs, nid in e.snes
            sne = getindex(model,nid)
            @match e.type begin
                CTL_Event(1) => 
                             push!(ntw_changes,nid)
                CTL_Event(2) =>
                             start_mnt!(sne,model.ticks)
                CTL_Event(3) =>
                             stop_mnt!(sne)
                _ => log_info(model.ticks,a.id,"Control event not recognised: $e")
            end

        end

        if !isempty(ntw_changes)
            do_update_flows!(a,ntw_changes,model)
        end

        delete!(a.events,model.ticks)
    end
end

"""
Do preventive maintenance activities for the assets controlled by the given agent.
"""
function do_maintenance_step!(a::Agent,mnt_policy::Type{T},model::ABM) where T<:MaintenanceType

    #prediction
    if model.ticks%a.maintenance.predictive_freq == 0
        window_size = a.maintenance.prediction_window
        #sort snes by id, works either for centralised (all assets one control agent or decentralised 1 asset per agent) #TODO decentralised with more than 1 asset per agent.
        # sne_ids = sort(collect(get_controlled_assets(a.id,model)))
        sne_ids = collect(1:nv(a.params[:base_ntw_graph]))

        snes = getindex.([model],sne_ids)
        
        log_info(model.ticks,a.id,"sne_ids: $(sne_ids)")
        
        #arrange predictions in a matrix of dims: length(snes) x window_size.
        ruls_pred = permutedims(hcat(get_rul_predictions.(snes,[model.ticks],[window_size])...))
        a.rul_predictions = length(a.rul_predictions) > 0 ? hcat(a.rul_predictions,ruls_pred) : ruls_pred
        # log_info(model.ticks,a.id," length: $(size(a.rul_predictions)) rul pred: $(a.rul_predictions)")
        log_info(model.ticks,a.id,"Pred Maint=> services: $(model.ntw_services))")

        update_maintenance_plan!(a,mnt_policy,model)
    end
    
    #check a.pending_jobs if any job for the current tick, if so start
    ntw_changes::Vector{Int64} = []
    if haskey(a.maintenance.pending_jobs_start,model.ticks)
        for nid in a.maintenance.pending_jobs_start[model.ticks]
            push!(ntw_changes,-1 * nid )
            sne = getindex(model,nid)
            start_mnt!(sne,model.ticks)
        end
        delete!(a.maintenance.pending_jobs_start,model.ticks)
    end

    if haskey(a.maintenance.pending_jobs_stop,model.ticks)
        for nid in a.maintenance.pending_jobs_stop[model.ticks]
            push!(ntw_changes,nid)
            sne = getindex(model,nid)
            stop_mnt!(sne)
        end
        delete!(a.maintenance.pending_jobs_stop,model.ticks)
    end

    if !isempty(ntw_changes)
        do_update_flows!(a,ntw_changes,model)
    end

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

function MaintenanceInfoCorrective(deterioration::Float64,model)
    # TODO adjust to multiple eul. For time being, always 100. 
    return MaintenanceInfo(CorrectiveM,100,-1,model.mnt_wc_duration,model.mnt_wc_cost,0,0,0,deterioration,model.mnt_wc_duration,model.mnt_wc_cost)
end
function MaintenanceInfoCorrective(model)
    MaintenanceInfoCorrective(1.,model)
end
function MaintenanceInfoPreventive(deteriation::Float64,model)
    return MaintenanceInfo(PreventiveM,100,-1,model.mnt_bc_duration,model.mnt_bc_cost,20,10,10,deteriation,model.mnt_wc_duration,model.mnt_wc_cost)
end
function MaintenanceInfoPreventive(model)
    MaintenanceInfoPreventive(1.,model)
end
function MaintenanceInfoPredictive(deterioration::Float64,model)
    return MaintenanceInfo(PredictiveM,100,-1,model.mnt_bc_duration,model.mnt_bc_cost,20,10,10,deterioration,model.mnt_wc_duration,model.mnt_wc_cost)
end
function MaintenanceInfoPredictive(model)
    MaintenanceInfoPredictive(1.,model)
end

