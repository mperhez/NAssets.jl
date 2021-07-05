"""
   Function to deteriorate a network element
"""
function deteriorate!(sne::SimNE)
    state = get_state(sne)
    if state.up
        state.rul = state.rul - 1

        if state.rul <= 0
            state.up = false
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
    state = get_state(sne)
    state.rul = rand(70:100,nv(model.ntw_graph))[sne.id]
    set_state!(sne,state)
end

