# function do_corrective_man()
#     if trigger_maintenance
        
#     end
# end
# function do_preventive_man()
#     if trigger_maintenance
        
#     end
# end
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


function do_maintenance(sne::SimNE)
    if MAINTENANCE_Action(1)
        state = get_state(sne)
        state.up = false
        state.on_maintenance = true
        set_state!(sne,state)
    elseif MAINTENANCE_Action(2)
        state = get_state(sne)
        state.up = true
        state.on_maintenance = false
        state.maintenance_due = get_next_maintenance_due(sne)
        set_state!(sne,state)
    end
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

    sne.maintenance.policy = model.mnt_policy
    sne.maintenance.duration = sne.maintenance.policy == CorrectiveM ? model.mnt_wc_duration : model.mnt_bc_duration
    sne.maintenance.threshold = model.mbt_threshold

    state = get_state(sne)
    #init with according to factory estimated parameters
    state.maintenance_due = state.rul_e - sne.maintenance.threshold
    set_state!(sne,state)
end


function start_mnt(sne::SimNE,time_start::Int64)
    sne.maintenance.job_start = time_start
    state = get_state(sne)
    state.up = false
    state.on_maintenance = true
    set_state!(sne,state)
end

function stop_mnt!(sne::SimNE)
    sne.maintenance.job_start = -1
    state = get_state(sne)
    state.up = true
    state.on_maintenance = false
    state.maintenance_due = 
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



function is_start_mnt(sne::SimNE,mnt_policy::CorrectiveM,model::ABM)
    return !get_state(sne).up
end

function is_start_mnt(sne::SimNE,mnt_policy::PredictiveM,model::ABM)
    return get_state(sne).mnt_due == model.ticks
end

function is_start_mmnt(sne::SimNE,mnt_policy::PreventiveM,model::ABM)
    return get_state(sne).mnt_due == model.ticks
end


