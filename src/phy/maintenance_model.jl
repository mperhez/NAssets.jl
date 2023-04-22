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


function init_maintenance!(sne::SimNE,model::ABM)
    state = get_state(sne)
    #init with according to factory estimated parameters
    state.rul_e = state.rul
    state.maintenance_due = state.rul_e - Int(round(sne.maintenance.threshold))
    set_state!(sne,state)
end

"""
`start_mnt!(a::Agent,sne::SimNE,model::ABM)`

It simulates start of maintenance.

"""
function start_mnt!(a::Agent,sne::SimNE,model::ABM)
    log_info(model.ticks,a.id,"Starting mnt... $(sne.id)")
    sne.maintenance.job_start = model.ticks
    state = get_state(sne)
    state.up = false
    #state.rul = 0
    state.on_maintenance = true
    set_state!(sne,state)
    drop_node!(sne,model)
    finish_mnt = model.ticks + sne.maintenance.duration
    log_info(model.ticks,a.id,"schedulling up of $(sne.id) for... $(finish_mnt)")
    schedule_event!(a,CTL_Event(3),finish_mnt,[sne.id])
end

"""
`stop_mnt!(a::Agent,sne::SimNE,model::ABM)`

It simulates completion of maintenance, refilling RUL and rejoining asset to the network.

"""
function stop_mnt!(a::Agent,sne::SimNE,model::ABM)
    # log_info(model.ticks,a.id,"Stopping mnt...$(sne.id)---will restore to eul: $(sne.maintenance.eul)")
    state = get_state(sne)
    state.up = true
    state.on_maintenance = false
    state.rul = sne.maintenance.eul - 1.
    state.maintenance_due = sne.maintenance.job_start + sne.maintenance.duration + sne.maintenance.eul - Int(round(sne.maintenance.threshold))
    sne.maintenance.job_start = -1
    set_state!(sne,state)
    rejoin_node!(model,sne.id)
    #Only if the agent's maintenance policy is corrective??
    # if sne.maintenance.policy == CorrectiveM
        schedule_event!(a,CTL_Event(1), model.ticks + 2, [sne.id])
        # log_info(model.ticks,a.id," Event...$(CTL_Event(1)) scheduled for $(sne.id) at $(model.ticks + 2) ")
    # end
end

function start_mnt!(sne::SimNE,time_start::Int64,mnt_policy::Type{CorrectiveM})
    # log_info(time_start,sne.id,"Starting corrective maintenance...")
    
    start_mnt!(sne,time_start)


end

function start_mnt!(sne::SimNE,time_start::Int64,mnt_policy::Type{PreventiveM})
    log_info(time_start,sne.id,"Starting preventive maintenance..")
end

function stop_mnt!(sne::SimNE,mnt_policy::Type{CorrectiveM},model::ABM)
    # log_info(model.ticks,sne.id,"Stopping corrective maintenance for $(nv(model.ntw_graph))...")
    rejoin_node!(model,sne.id)
    stop_mnt!(sne)
    # log_info(model.ticks,sne.id,"Stopped maintenance for $(nv(model.ntw_graph))...")
end

function stop_mnt!(sne::SimNE,mnt_policy::Type{PreventiveM},model::ABM)
    log_info(model.ticks,sne.id,"Stopping preventive maintenance..") 
end


function get_rul_predictions(sne::SimNE,current_time::Int64,window_size::Int64)::Vector{Float64}
    rul = [ st.rul for st in sne.state_trj ]
    
    return  [ first(sne.maintenance.prediction)(rul,t,(last(sne.maintenance.prediction,size(sne.maintenance.prediction,2)-1)...)) for t = 1 : window_size ]
end


"""
Schedules an event of type ``type`` on the given agent ``a`` at time ``time``, affecting the snes with ids: ``snes``.
"""
function schedule_event!(a::Agent,type::CTL_Event,time::Int64,snes::Vector{Int64})
    if !haskey(a.events,time)
        a.events[time] = Array{ControlEvent,1}()
    end
    push!(a.events[time],ControlEvent(time,type,snes))
end

"""
Schedules an event of type ``type`` on the given agent ``a`` at time ``time``.
"""
function schedule_event!(a::Agent,type::CTL_Event,time::Int64)
    schedule_event!(a,type,time,Array{Int64,1}())
end


"""
`update_maintenance_plan!(a::Agent,mnt_policy::Type{PreventiveM},model::ABM)`

It schedules maintenance events (start/stop maintenance) for assets under control of `a` that are configured with preventive or predictive `mnt_policy`

"""
function update_maintenance_plan!(a::Agent, sne_ids_pred::Array{Int64},model::ABM)
    

    window_size = a.maintenance.prediction_window
    #use the maintenance window from the end - window size
    ruls = a.rul_predictions[:,size(a.rul_predictions,2)-window_size+1:size(a.rul_predictions,2)]
    
    for i=1:size(ruls,1)
        sne = getindex(model,sne_ids_pred[i])

        if !get_state(sne).on_maintenance && sne.id in sne_ids_pred
            #sum all where rul is <= threshold, if any > 0, then sum > 0
            cruls = ruls[i,size(ruls,2)-window_size+1:size(ruls,2)]
            
            threshold_reached = sum(cruls .<= a.maintenance.threshold) > 0
            if threshold_reached#!isempty(threshold_reached)
                #negative indicates i goes down for maintenance
                #1st reroute traffic out of node
                schedule_event!(a,CTL_Event(1),model.ticks + minimum(threshold_reached),[-1*sne.id])
                #2nd perform maintenance
                schedule_event!(a,CTL_Event(2),model.ticks + minimum(threshold_reached)+2,[-1*sne.id])
                # log_info(model.ticks,a.id," Event scheduled for $(a.id) -> $i at $(model.ticks + minimum(threshold_reached)+2)....$([-1*sne.id])")
            end
        end
    end
end


"""
  It processes a route received from optimisation algorithm
"""
function process_route!(a::Agent,rw,model::ABM)
    log_info(model.ticks,a.id,"full rw: $(rw)")
    path = Array{Int64,1}()
    services = model.ntw_services
    hd =  first(services[Int(rw[2])])
    route = rw[3:end]
    i_nxt = hd
    

    while true
        push!(path,i_nxt)
        i_nxt = Int(route[i_nxt])
        if i_nxt == 0 
           # && i_nxt != last(model.ntw_services[rw[2]])
           break           
        end
    end
    
    snes = [ getindex(model,Int(sid)) for sid in path ]
    time = maximum([ !is_up(sne) ? sne.maintenance.job_start + sne.maintenance.duration : model.ticks + Int(rw[1]) for sne in snes ])

    # log_info(model.ticks,a.id," $(rw[1:3]) event scheduled for t=$(time) ==> path: $path ")
    schedule_event!(a,CTL_Event(5),time,path)
end

"""
`update_maintenance_plan!(a::Agent,mnt_policy::Type{PreventiveM},model::ABM)`

It schedules maintenance events (start/stop maintenance) for assets under control of `a` that are configured with predictive `mnt_policy` with maintenance planning running in python.

"""
function update_maintenance_plan!(a::Agent,mnt_policy::Type{PredictiveM},model::ABM)
    window_size = a.maintenance.prediction_window * 2
    ruls = a.rul_predictions[:,size(a.rul_predictions,2)-window_size+1:size(a.rul_predictions,2)]
    
    #optimal plan is precomputed offline for large networks
    if nv(model.ntw_graph) > 90
        if model.ticks == 10 # It only does this one time as the plans and routes are precomputed
            mnt_plan, routes = ln_mnt_plan, ln_routes
        else
            mnt_plan, routes = [],[]
        end

    else
        #data conversion to py, minus 1 as indexes in py start in 0
        services_py = model.py_integration.np.matrix(model.ntw_services) .- 1
        ruls_py = model.py_integration.np.matrix(ruls)
        #pycall to optimisation function

        mnt_plan, routes = model.py_integration.opt_run.maintenance_planning(model.ticks,services_py, ruls_py)
    end

    if !isempty(routes) && !isempty(mnt_plan)
        #when necessary, convert routes output to matrix, where size(ruls,1) + 2 is length of each routes matrix row.
        if size(routes,2) != size(ruls,1) + 2
            routes = transpose(reshape(routes,size(ruls,1) + 2,:))
        end

        
        #convert routes from py to julia indexes
        routes = routes .+ 1

        if size(routes,2) > 1
            for rw in eachrow(routes)
                process_route!(a,rw,model)
            end
        elseif size(routes,2) == 1
            process_route!(a,routes,model)
        end

        for sne_id in 1:length(mnt_plan) 
            if mnt_plan[sne_id] > 0
                # negative indicates that sne_id goes down for maintenance
                log_info(model.ticks,a.id," event for: $(mnt_plan[sne_id])")
                schedule_event!(a,CTL_Event(2),Int(model.ticks+mnt_plan[sne_id]),[sne_id])
            end
        end
    end
end


"""
It processes scheduled events
"""
function do_events_step!(a::Agent,model::ABM)
    
    if haskey(a.events,model.ticks)
        evs = a.events[model.ticks]
        ntw_changes = Array{Int64,1}()
        
        for e in evs
            # log_info(model.ticks,a.id,"Triggering event: $e")
            @match e.type begin
                CTL_Event(1) => 
                            for nid in e.snes
                                sne = getindex(model,abs(nid))
                                push!(ntw_changes,nid)
                            end
                CTL_Event(2) =>
                            for nid in e.snes
                                sne = getindex(model,abs(nid))
                                start_mnt!(a,sne,model)
                            end
                CTL_Event(3) =>
                            for nid in e.snes
                                sne = getindex(model,nid)
                                stop_mnt!(a,sne,model)
                            end
                CTL_Event(4) =>
                            do_rul_predictions!(a,e.snes,model)
                
                CTL_Event(5) =>
                            do_update_flows_from_path!(a,e.snes,model)
                
                _ => log_info(model.ticks,a.id,"Control event not recognised: $e")
            end

        end

        if !isempty(ntw_changes)
            do_update_flows_from_changes!(a,ntw_changes,model)
        end

        delete!(a.events,model.ticks)
    end
end

"""
Run RUL predictions for the assets controlled by agent ``a``
"""
function do_rul_predictions!(a::Agent,sne_ids_pred::Array{Int64},model::ABM)
    window_size = a.maintenance.prediction_window * 2
    log_info(model.ticks,a.id,"Running RUL predictions..
    .")
    #sort snes by id, works either for centralised (all assets one control agent or decentralised 1 asset per agent) #TODO decentralised with more than 1 asset per agent.
    #sne_ids = collect(1:nv(a.base_ntw_graph))
    snes = [ sne for sne in getindex.([model],sne_ids_pred) ]
    log_info(model.ticks,a.id,"predicting for snes: $(sne_ids_pred)")
    
    #arrange predictions in a matrix of dims: length(snes) x window_size.
    ruls_pred = permutedims(hcat(get_rul_predictions.(snes,[model.ticks],[window_size])...))
    

    a.rul_predictions = length(a.rul_predictions) > 0 ? hcat(a.rul_predictions,ruls_pred) : ruls_pred
    # log_info(model.ticks,a.id," length: $(size(a.rul_predictions)) rul pred: $(a.rul_predictions)")
    # log_info(model.ticks,a.id,"Pred Maint=> services: $(model.ntw_services))")
    if !isempty(sne_ids_pred)
        update_maintenance_plan!(a,sne_ids_pred,model)
    end
    #collect(get_controlled_assets(a.id,model))
    #run next prediction
    schedule_event!(a,CTL_Event(4),model.ticks+a.maintenance.predictive_freq,sne_ids_pred)
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

function MaintenanceInfoCorrective(deterioration::Array{Any},prediction::Array{Any},model)
    # TODO adjust to multiple eul. For time being, always 100. 
    return MaintenanceInfo(CorrectiveM,100,-1,model.mnt_wc_duration,model.mnt_wc_cost,0.1,prediction,model.predictive_freq,model.prediction_window,deterioration,model.mnt_wc_duration,model.mnt_wc_cost)
end
function MaintenanceInfoCorrective(model)
    MaintenanceInfoCorrective([],[],model)
end
function MaintenanceInfoPreventive(deterioration::Array{Any},prediction::Array{Any},model)
    return MaintenanceInfo(PreventiveM,100,-1,model.mnt_bc_duration,model.mnt_bc_cost,10.,prediction,model.predictive_freq,model.prediction_window,deterioration,model.mnt_bc_duration,model.mnt_bc_cost)
end
function MaintenanceInfoPreventive(model)
    MaintenanceInfoPreventive([],[],model)
end
function MaintenanceInfoPredictive(deterioration::Array{Any},prediction::Array{Any},model)
    return MaintenanceInfo(PredictiveM,100,-1,model.mnt_bc_duration,model.mnt_bc_cost,20.,prediction,model.predictive_freq,model.prediction_window,deterioration,model.mnt_bc_duration,model.mnt_bc_cost)
end
function MaintenanceInfoPredictive(model)
    MaintenanceInfoPredictive([],[],model)
end

function MaintenanceInfoCustom(deterioration::Array{Any},prediction::Array{Any},model)
    return MaintenanceInfo(CustomM,100,-1,model.mnt_bc_duration,model.mnt_bc_cost,10.,prediction,model.predictive_freq,model.prediction_window,deterioration,model.mnt_bc_duration,model.mnt_bc_cost)
end
function MaintenanceInfoCustom(model)
    MaintenanceInfoCustom([],[],model)
end

### TODO REVIEW ##
#maintenance cost
cost(av) = (1 - av) * 100

"""
Maintenance cost at a given time step:

rul_mnt: rul of an asset (sne) of the network that is undergoing maintenance. If rul == 0., then it is corrective maintenance, if rul > 0, then it is preventive maintenance. Otherwise (-1) no maintenance ongoing.

is_start: indicates if maintenance has just started so time-independent costs are added

is_active: indicates if the asset was active in the network before maintenance started, i.e. was part of an active flow.

dt_cost: downtime cost, cost of service flow/production loss per time step, time-dependent. Added when corrective maintenance.

l_cost: labour cost per time step, time-dependent. 

p_cost: parts costs for maintenance regardless of the time it takes, time-independent, only added when maintenance starts.

r_cost: cost of loss of remaining life. Added when preventive maintenance. 
"""
function maintenance_cost(rul_mnt,is_start,is_active,dt_cost,l_cost,p_cost,r_cost)

    #parts costs
    mnt_cost = is_start ? p_cost : 0.

    #labour costs
    mnt_cost += rul_mnt >= 0. ? l_cost : 0.

    #downtime costs
    mnt_cost += rul_mnt == 0. && is_active ? dt_cost : 0.

    #loss of life costs
    mnt_cost += is_start ? rul_mnt * r_cost : 0.
    
end

# Loads offline plans, it assummes that plans are generated in advance and rerouting takes place before scheduled maintenance.
function load_offline_plan!(a::Agent,snes::Array{Int64},model::ABM)
    mnt_plan = model.offline_plan

    # log_info(model.ticks,a.id,"Update CUSTOM MNT PLAN $mnt_plan")

    #schedule re-routing
    for trr=10:10:model.n_steps
        planned_down = mnt_in_range(mnt_plan,0,10)
        if !isempty(planned_down)
            #NetworkChange
            # log_info(a,model.ticks," planned down: schedulling network change as: $(planned_down)")
            schedule_event!(a,CTL_Event(1), minimum(planned_down) - 4, planned_down .* -1)
        end
    end
    #schedule mnt jobs
    for sne_id in snes
        # Extract the j-th column
        sne_plan = filter(x->x!=0,mnt_plan[:, sne_id])
        # time_btwn = diff(sne_plan)
        for mnt_job in sne_plan 
            # log_info(model.ticks,sne_id," ===> mnt to start at: $(Int(model.ticks+mnt_job))")
            schedule_event!(a,CTL_Event(2),Int(model.ticks+mnt_job),[sne_id])
        end
    end
    
    
    
end

"""
Return mnt jobs in a given range for the passed plan
"""
function mnt_in_range(mnt_plan::Array{Int,2}, from::Int, to::Int)
    snes_mnt = Vector{Int}()
    for j in 1:size(mnt_plan, 2)
        for i in 1:size(mnt_plan, 1)
            if mnt_plan[i, j] >= from && mnt_plan[i, j] <= to
                push!(snes_mnt, j)
                break
            end
        end
    end
    return snes_mnt
end

