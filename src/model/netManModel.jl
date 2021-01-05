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

    #space = GraphSpace(G)
    space = GridSpace(grid_dims, moore=true)
    #space = ContinuousSpace(2; periodic = true, extend = grid_dims)
    #agent_types = Union{}
    agent_types = Agent
    model = ABM(agent_types, space; scheduler = random_activation, properties = props)
    create_agents!(args[:q],model)
    model
end

"""
    Initialization with adjacency matrix
"""
function initialize(A,args,user_props;grid_dims=(20,20),seed=0)
    # Global model props
    default_props = Dict(
        :ticks => 0, # time unit
        :maxT => 10,
        :Τ => args[:Τ],
        :ΔΦ => args[:ΔΦ]
    )
    props = merge(default_props,user_props)
    space = GridSpace(grid_dims, moore=true)
    agent_types = Agent
    model = ABM(agent_types, space; scheduler = random_activation, properties = props)
    q =nv(model.graph)
    @show q
    create_agents!(q,:black,ϕ,model)
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
Create agents receiving a behaviour function
"""

function create_agents!(q::Int64,color::Symbol,f,model)
    for _ in 1:q
        next_fire = rand(1:model.:maxT)
        id = nextid(model)
        neighbors = outneighbors(model.graph,id)
        @show id neighbors
        a = add_agent!(
            Agent(id,(rand(1:20),rand(1:20)),color,next_fire,next_fire,neighbors,[],:FIFO,f),
            model)
    end
end

"""
    It advance model one step. Agents are progressed here to ensure that one action is perform in
    all agents before the next action is performed in all agents, instead of having one action
    executed in some agents and then some start with second action.
"""
function model_step!(model)
    model.ticks += 1
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
    gif(anim, "firefly.gif", fps = 3), df
end

# function run_model(A,n,args,properties;agent_data)
#     model = initialize(A,args,properties;seed=123)
#
#     agent_color(a::Agent) = a.color
#     agent_shape(a::Agent) = :circle
#     agent_size(a::Agent) = 7
#     plot_scheduler = model.scheduler
#
#     plotkwargs = (
#         ac = agent_color, am = agent_shape, as = agent_size,
#         scheduler = plot_scheduler, aspect_ratio = 1, size = (600, 600), showaxis = false,
#     )
#
#     #p = plotabm(model; plotkwargs...)
#     df = init_agent_dataframe(model,agent_data)
#     anim = @animate for i in 0:n
#             p = plotabm(model;background_color=:black, plotkwargs...)
#             title!(p, "step $(i)")
#             step!(model, agent_step!, model_step!)
#             collect_agent_data!(df, model, agent_data, i)
#         end
#     gif(anim, "firefly.gif", fps = 3), df
# end
