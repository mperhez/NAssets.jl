"""
   Function to deteriorate a network element
"""
function deteriorate!(sne::SimNE)
    state = get_state(sne)
    if state.up
        # if sne.id == 5
        #     state.rul = state.rul - 3
        # else
            state.rul = state.rul - 1
        # end

        if state.rul <= 0
            state.up = false
            #state.rul = 100
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
    sne.eul = 100 # For time being, always 100. 
    state = get_state(sne)
    #randomly initialize condition of sne
    state.rul = rand((sne.eul-30):sne.eul,nv(model.ntw_graph))[sne.id]
    #set maitenance due time
    state.maintenance_due = model.ticks + state.rul
    set_state!(sne,state)
end

