"""
Basic initialization
"""
function initialize(args,user_props;grid_dims=(3,3),seed=0)
    pulses = []
    for i in 1:args[:q]
        push!(pulses,[])
    end

    # Global model props
    default_props = Dict(
        :ticks => 0,# # time unit
        :pulses=>pulses,
        :Τ => args[:Τ], # Max time steps to fire
        :ΔΦ => args[:ΔΦ]
    )

    Random.seed!(seed)
    props = merge(default_props,user_props)

    space = GridSpace(grid_dims, moore=true)
    agent_types = Agent
    model = ABM(agent_types, space; scheduler = random_activation, properties = props)
    create_agents!(args[:q],model)
    model
end

"""
Simplest create agents
"""

function create_agents!(q::Int64,model)
    for _ in 1:q
        #next_fire = rand(0:0.2:model.:Τ)
        s0 = SimpleAgState(zeros((2,2)),Vector{Float64}())
        id = nextid(model)
        a = add_agent!(
                Agent(id,s0),model
            )
    end
end

"""
    It advance model one step. Agents are progressed here to ensure that one action is perform in
    all agents before the next action is performed in all agents, instead of having one action
    executed in some agents and then some start with second action.
"""
function model_step!(model)
    model.ticks += 1
    
    @show model.ticks
    for a in allagents(model)
        #pulse(a,model)
        println(a.state.condition_trj)
    end
    # for a in allagents(model)
    #     #process_pulses(a,model)
    # end
end

"""
    Progress agents one step.
"""
function agent_step!(a::Agent,model)
    #placeholder
end


"""
Simple run model function
"""
function run_model(n,args,properties;agent_data)
    model = initialize(args,properties;seed=123)

    agent_color(a::Agent) = :white#a.color
    agent_shape(a::Agent) = :circle
    agent_size(a::Agent) = 7

    plot_scheduler = model.scheduler

    plotkwargs = (
            ac = agent_color, am = agent_shape, as = agent_size,
            scheduler = plot_scheduler, aspect_ratio = 1
            , size = (600, 600), showaxis = false
    )

    #p = plotabm(model; plotkwargs...)
    df = init_agent_dataframe(model,agent_data)
    anim = @animate for i in 0:n
            p = plotabm(model;background_color=:black, plotkwargs...)
            title!(p, "step $(i)")
            step!(model, agent_step!,model_step!)
            collect_agent_data!(df, model, agent_data, i)
        end
    gif(anim, plots_dir*"animation.gif", fps = 3), df
end
