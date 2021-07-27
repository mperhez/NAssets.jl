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


function trigger_maintenance(sne::SimNE)
    state = get_state(sne)
    # if state.maintenance_due == model.ticks

    # end
end

"""
It triggers maintenance when the asset is brokendown

"""
function do_corrective_man(sne::SimNE)
    state = get_state(sne)
    if !state.up
        trigger_maintenance(sne)
    end
end

"""
It triggers maitenance on due date assuming is before the asset breakdown
"""
function do_preventive_man(sne::SimNE,model::ABM)
    state = get_state(sne)
    if state.maintenance_due == model.ticks
        trigger_maintenance(sne)
    end
end

function init_maintenance!(sne::SimNE,model::ABM)
    state = get_state(sne)
    #init with according to factory estimated parameters
    state.maintenance_due = state.rul_e - sne.maintenance.threshold
    set_state!(sne,state)
end


function start_mnt!(sne::SimNE,time_start::Int64)
    log_info(time_start,sne.id,"Starting maintenance...")
    sne.maintenance.job_start = time_start
    state = get_state(sne)
    state.up = false
    state.on_maintenance = true
    set_state!(sne,state)
end

function stop_mnt!(sne::SimNE,model::ABM)
    log_info("Stopping maintenance for $(sne.id)...")
    state = get_state(sne)
    state.up = true
    state.on_maintenance = false
    state.maintenance_due = sne.maintenance.job_start + sne.maintenance.duration + sne.maintenance.eul - sne.maintenance.threshold
    sne.maintenance.job_start = -1
    set_state!(sne,state)
end


function get_rul_predictions(sne::SimNE,window_size::Int64)
    #control agent responsibility?
    predictions = Array{Float64}(window_size) # an array of size: window_size that will hold the predictions of RUL for this sne for the next window_size steps.
    #apply formula that
    return predictions
end

function do_predictive_mnt!(sne::SimNE,model::ABM)
    #control agent responsibility?
    #potentially check periodicity
    #update maitenance_due based on predictions
    if !get_state(sne).on_maintenance && model.ticks%sne.maintenance.predictive_freq == 0
        window_size = 10 # how many steps ahead the prediction is going to be for
        get_rul_predictions(sne,window_size)
    end
end

function do_maintenance_step!(sne::SimNE,model::ABM)
    #control agent responsibility?
   if is_start_mnt(sne,sne.maintenance.policy,model)
      start_mnt!(sne,model.ticks)
   end
   if sne.maintenance.job_start > 0 && sne.maintenance.job_start + sne.maintenance.duration == model.ticks
      stop_mnt!(sne)
   end
end



function is_start_mnt(sne::SimNE,mnt_policy::Type{CorrectiveM},model::ABM)
    return !get_state(sne).up && !get_state(sne).on_maintenance
end

function is_start_mnt(sne::SimNE,mnt_policy::PredictiveM,model::ABM)
    return get_state(sne).mnt_due == model.ticks
end

function is_start_mmnt(sne::SimNE,mnt_policy::PreventiveM,model::ABM)
    return get_state(sne).mnt_due == model.ticks
end

function MaintenanceInfoCorrective(model)
    # TODO adjust to multiple eul. For time being, always 100. 
    return MaintenanceInfo(CorrectiveM,100,-1,model.mnt_wc_duration,0,0)
end
function MaintenanceInfoPreventive(model)
    return MaintenanceInfo(PreventiveM,100,-1,model.mnt_bc_duration,10,0)
end
function MaintenanceInfoPredictive(model)
    return MaintenanceInfo(PredictiveM,100,-1,model.mnt_bc_duration,10,10)
end
