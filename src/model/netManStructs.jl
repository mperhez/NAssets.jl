export State
"""
Self-organising agent
"""

abstract type SOAgent <: AbstractAgent end
abstract type SimAsset <: AbstractAgent end
abstract type State end
abstract type Packet end

"""
    "Real" state of the asset
"""
mutable struct SimpleAssetState <: State
    color::Symbol
    condition_trj::Array{Float64,2}
    queue::Channel{Packet}
end

"""
    Agent's state, including observed state of 
    monitoring/controlling asset
"""
mutable struct SimpleAgState <: State
    color::Symbol
    condition_trj::Array{Float64,2}
    health_trj::Vector{Float64}
end



#fireflystate
mutable struct FFAgState <: State
    color::Symbol
    #T::Int64 # period to fire
    phase::Float64 #internal clock
    #inbox::Vector{Tuple{Int64,Float64}}
    inbox::Vector{Int64}
    blind::Int64
    maxN::Int64
    maxId::Int64
    condition_trj::Array{Float64,2}
    health_trj::Vector{Float64}
    #pulse_strategy::Symbol # FIFO, NEAR, MIXED
    #ϕ
end

"""
Indicates the type of a flow within a path
"""
@enum Flow_Type begin
    f_SE = -2 # start and end
    f_S = -1 # start
    f_I = 0 # intermediate
    f_E = 1 # end
end

mutable struct ModelState <: State
    tick::Int
    links_load::Dict{Tuple{Int,Int},Int} # key: (src,dst), value: pkts
    active_flows::Vector{Tuple{Int,Int,Flow_Type}} # source,destination,type
end

function ModelState(tick::Int)
    ModelState(tick,Dict(),[])
end


# function Agent(id,phase)
#     #:blue,phase,[],0,1,id,zeros((2,2))
#     Agent(id,rand(1:10),SimpleAgState(zeros((2,2),Vector{Float64}())))
# end

# function Agent(id,pos,state)
#     #:blue,phase,[],0,1,id,zeros((2,2))
#     Agent(id,pos,state)
# end



function SimpleAgState(condition_trj::Array{Float64,2}, health_trj::Vector{Float64})
    SimpleAgState(:red,condition_trj,health_trj)
end


