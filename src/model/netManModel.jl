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
        :ΔΦ => args[:ΔΦ],
        :ntw_graph => args[:ntw_graph],
        :ctl_graph => args[:ctl_graph],
        :mapping => Dict{Int64,Int64}(),
        :pkt_per_tick => 5 # How may packets can be processed per tick
    )

    Random.seed!(seed)
    props = merge(default_props,user_props)

    #space = GridSpace(grid_dims, moore=true)
    space = GraphSpace(props[:ntw_graph])
    agent_types = Union{SimNE,Agent}
    model = ABM(agent_types, space; scheduler = random_activation, properties = props)
    #create 
    create_agents!(model)
    model
end

# """
# Simplest create agents
# """

# function create_agents!(q::Int64,model)
#     for _ in 1:q
#         #next_fire = rand(0:0.2:model.:Τ)
#         s0 = SimpleAgState(zeros((2,2)),Vector{Float64}())
#         id = nextid(model)
#         a = add_agent!(
#                 Agent(id,s0),model
#             )
#     end
# end


"""
Simplest create agents
"""

function create_agents!(model)
    
    # create SimNE
    for i in 1:nv(model.properties[:ntw_graph])
        #next_fire = rand(0:0.2:model.:Τ)
        s0 = NetworkAssetState(zeros(2,2))
        id = nextid(model)
        @show i
        a = add_agent_pos!(
                SimNE(id,i,s0),model
            )
    end

    #create control agents 1:1
    for i in 1:nv(model.properties[:ntw_graph])
        #next_fire = rand(0:0.2:model.:Τ)
        s0 = SimpleAgState(zeros((2,2)),Vector{Float64}())
        id = nextid(model)
        set_control_agent!(i,id,model)
        a = add_agent_pos!(
                Agent(id,i,s0),model
            )
    end


    for i in 1:nv(model.properties[:ntw_graph])
        @show get_node_agents(i, model)
    end

end



"""
    It advance model one step. Agents are progressed here to ensure that one action is perform in
    all agents before the next action is performed in all agents, instead of having one action
    executed in some agents and then some start with second action.
"""
function model_step!(model)
    model.ticks += 1
    
    pkt = DPacket(1,1,7,10,model.ticks,4)

    net_elm = find_agent(1,model)
    put!(net_elm.state.queue,(0,pkt))


    # @show model.ticks
    # for a in allagents(model)
    #     #pulse(a,model)
    #     println(a.state.condition_trj)
    # end
    # for a in allagents(model)
    #     #process_pulses(a,model)
    # end
end

"""
    Progress control agents one step.
"""
function agent_step!(a::Agent,model)
    #placeholder
    if model.ticks == 5 && a.id == 6
        a.color = :pink
    else
        a.color = :lightblue
    end
end

"""
    Progress SimNE one step.
"""
function agent_step!(a::SimNE,model)
    #placeholder
    # if model.ticks == 5 && a.id == 3
    #     a.color = :red
    # else
    #     a.color = :lightgray
    # end
    in_packet_processing(a,model)
end

"""
Simple run model function
"""
function run_model(n,args,properties;agent_data)
    model = initialize(args,properties;seed=123)

    
    # agent_shape(a::Agent) = :square
    agent_size(a) = 7
    # agent_size(a::Agent) = 7

    plot_scheduler = model.scheduler#by_type((SimNE,Agent), false)#

    plotkwargs = (
            # ac = agent_color, am = agent_shape, as = agent_size,
            # scheduler = plot_scheduler, aspect_ratio = 1
            # #Graph space properties
            # , method = :circular, node_size = 0.2
            # , 
            size = (600, 600), showaxis = false
    )

    #p = plotabm(model; plotkwargs...)
    df = init_agent_dataframe(model,agent_data)
    anim = @animate for i in 0:n
            p = plotabm_networks(model; plotkwargs...)
            title!(p, "step $(i)")
            step!(model, agent_step!,model_step!)
            collect_agent_data!(df, model, agent_data, i)
        end
    println(model)
    gif(anim, plots_dir*"animation.gif", fps = 1), df
end

function agent_color(a)
    @show typeof(a)
    return :blue#a.color
end
        
    # agent_color(a::Agent) = :black#a.color
# function agent_shape(a)
#    #[println(c.shape) for c in a] 
   
#    return [c.shape for c in a] 
# end