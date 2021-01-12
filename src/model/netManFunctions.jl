export ϕ
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