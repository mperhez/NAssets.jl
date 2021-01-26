
"""
Self-organising agent
"""

abstract type SOAgent <: AbstractAgent end
abstract type SimAsset <: AbstractAgent end
abstract type State end

"""
    "Real" state of the asset
"""
mutable struct SimpleAssetState <: State
    color::Symbol
    condition_trj::Array{Float64,2}    
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
    Control Agent
"""
mutable struct Agent <: SOAgent
    id::Int64
    pos::Int64
    color::Symbol
    size::Float16
    state::SimpleAgState
end

"""
    Simulated Physical Network Element
"""
mutable struct SimNE <: SimAsset
    id::Int64
    pos::Int64
    color::Symbol
    size::Float16
    state::SimpleAssetState
end

# function Agent(id,phase)
#     #:blue,phase,[],0,1,id,zeros((2,2))
#     Agent(id,rand(1:10),SimpleAgState(zeros((2,2),Vector{Float64}())))
# end

# function Agent(id,pos,state)
#     #:blue,phase,[],0,1,id,zeros((2,2))
#     Agent(id,pos,state)
# end

function SimpleAssetState(condition_trj::Array{Float64,2})
    SimpleAssetState(:blue,condition_trj)
end

function SimpleAgState(condition_trj::Array{Float64,2}, health_trj::Vector{Float64})
    SimpleAgState(:red,condition_trj,health_trj)
end

function SimNE(id,nid,state)
     SimNE(id,nid,:gray,0.3,state)
end
function Agent(id,nid,state)
    Agent(id,nid,:lightblue,0.1,state)
end


