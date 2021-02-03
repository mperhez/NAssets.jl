export ϕ

@enum ControlModel CENTRALISED=1 DISTRIBUTED=2

function ϕ(t,T,pulse)
    α = 0.5
    Β = 0.5
    if isnothing(pulse)
        new_phase = t > 0 ? t - 1 : T  # phase function
    else
        new_phase = round(α * t + Β)
    end
end
"""
Agent emits pulse
"""
# function pulse(agent,model)
#     if(agent.phase == agent.T)
#         agent.color = :white
#
#         for n in agent.neighbors
#             na = first(filter(a->a.id == n,Set(allagents(model))))
#             push!(na.inbox,(agent.id, model.graph.weights[agent.id,na.id]))
#         end
#     else
#         agent.color = :black
#     end
# end

function update_neighbours(agent,model)
    neighbours = space_neighbors(agent,model,1)
    for n in neighbours
        ag_n = find_agent(n,model)
        push!(ag_n.inbox,agent.id)
    end
end

function pulse(agent,model)
    if(round(agent.phase,digits=2) == model.:Τ)
        agent.color = :white
        update_neighbours(agent,model)
        agent.phase = 0.0
    else
        agent.color = :blue
    end
end


"""
Agent processes pulses "observed"/"received" from neighbors
"""
function process_pulses(agent,model)
    if agent.phase < model.:Τ
        agent.phase = round(agent.phase + 0.1,digits=2)
    else
        agent.phase = round(agent.phase - model.:Τ,digits=2)
    end

    if !isempty(agent.inbox)
        if length(agent.inbox) > agent.maxN
            agent.phase = round(min(model.:Τ,agent.phase+model.:ΔΦ),digits=2)
            agent.maxN = length(agent.inbox)
        elseif length(agent.inbox) == agent.maxN &&
                maximum(agent.inbox) > agent.maxId
            agent.phase = round(min(model.:Τ,agent.phase+model.:ΔΦ),digits=2)
            agent.maxId = maximum(agent.inbox)
        end
    end
agent.inbox = []
end


function pulse_received(pulses,strategy)
    return if length(pulses) > 1
        @match strategy begin
        :NEAR  =>
                # This seems the most sensible, as all are received simoultaneosuly
                # intensity (greater distance less intensity)
                last(sort(pulses,by=x->x[2]))
        :MIXED =>
                #intensity and fraction of time step (distance * index)
                #TODO review: as intensity distance may need to be reversed and then multiplied
                # by index, then get the first.
                last(sort(pulses,by=x->findfirst(isequal(x),pulses)*x[2]))
        _     =>
                #FIFO
                first(pulses)
        end
    elseif isempty(pulses)
        Nothing
    else
        first(pulses)
    end
end

"""
Find agent in the model given the id
"""
function find_agent(id,model)
    first(filter(a->a.id == id,Set(allagents(model))))
end

"""
    load the graph of the network to control
"""

function load_network_graph()
    Random.seed!(123)
    #ntw = smallgraph("house")
    ntw = watts_strogatz(10,4,0.8)
    #gplot(ntw,layout=circular_layout,nodelabel=nodes(ntw))
    return ntw
end


"""
    load the graph of the control system
"""

function load_control_graph()
    Random.seed!(123)
    ntw = complete_graph(1)# watts_strogatz(25,4,0.8)
    #gplot(ntw,layout=circular_layout,nodelabel=nodes(ntw))
    return ntw
end

function plotabm_networks_multi(
    model;
    kwargs...,
)

    nsize = 0.13
    lwidth = 0.5

    l = @layout [a{1w};b]
    ntw_p = graphplot(
        model.ntw_graph
        ,names = 1:nv(model.ntw_graph)
        , method = :circular
        ,size=(300,200)
        ,node_weights = [ i > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]
        ,nodeshape = :hexagon
        ,nodecolor = [ getindex(model,i).color for i in 1:nv(model.ntw_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor=:dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,titlefontsize=1
        ,titlefontcolor=:white
    )
    
    annotate!((-0.4,0.75,Plots.text("Asset Network", 11, :black, :center)))

    ctl_p = graphplot(
        model.ctl_graph
        ,names = [ get_control_agent(i,model) for i in 1:nv(model.ctl_graph) ]
        , method = :circular
        ,size=(300,200)
        ,node_weights = [ i > 9 ? 1 : 1 for i in 1:nv(model.ctl_graph)]
        ,nodeshape = :circle
        ,nodecolor = [ getindex(model,get_control_agent(i,model)).color for i in 1:nv(model.ctl_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor=:dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,edgestyle = :dot
        ,curves = false
    )
    annotate!((-0.4,0.72,Plots.text("Control Network", 11, :black, :center)))

    p = Plots.plot(ctl_p,ntw_p, layout=l, size=(300,600))
    
    return p

end


function plotabm_networks_mono(
    model;
    kwargs...,
)

    nsize = 0.13
    lwidth = 0.5

    l = @layout [a{1w};b]
    ntw_p = graphplot(
        model.ntw_graph
        ,names = 1:nv(model.ntw_graph)
        , method = :circular
        ,size=(300,200)
        ,node_weights = [ i > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]
        ,nodeshape = :hexagon
        ,nodecolor = [ getindex(model,i).color for i in 1:nv(model.ntw_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor=:dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,titlefontsize=1
        ,titlefontcolor=:white
    )
    
    annotate!((-0.4,0.75,Plots.text("Asset Network", 11, :black, :center)))

    #p = Plots.plot(ntw_p, layout=l, size=(300,600))
    
    return ntw_p

end

function plotabm_networks(
    model;
    kwargs...
)
    if nv(model.ctl_graph) > 1
        return plotabm_networks_multi(model;kwargs...)
    else
        return plotabm_networks_mono(model;kwargs...)
    end
end



function get_control_agent(asset_id::Int,model)
    return model.mapping[asset_id]
end

function get_controlled_assets(agent_id::Int,model)
    assets = filter(k->model.mapping[k] == agent_id,keys(model.mapping))
    #println("assets controlled by $(agent_id) are: $(length(assets))")
    return assets
end

function set_control_agent!(asset_id::Int, agent_id::Int, model)
    getindex(model,asset_id).controller_id = agent_id
    #TODO Consider removing this line below
    #To avoid putting info in model
    model.mapping[asset_id] = agent_id
end

function flow_table(a::AbstractAgent)
    @match a begin
        a::SimNE => a.state.flow_table
        _ => []
    end
end