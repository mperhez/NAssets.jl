export soAgent

"""
Self-organising agent
"""

abstract type SOAgent <: AbstractAgent end
abstract type State end

mutable struct SimpleAgState <: State
    condition_trj::Array{Float64,2}
    healt_trj::Vector{Float64}
end

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
    healt_trj::Vector{Float64}
    #pulse_strategy::Symbol # FIFO, NEAR, MIXED
    #ϕ
end


mutable struct Agent <: SOAgent
    id::Int64
    pos::NTuple{2,Int64}
    state::SimpleAgState
end

function Agent(id,phase)
    #:blue,phase,[],0,1,id,zeros((2,2))
    Agent(id,(rand(1:10),rand(1:10)),SimpleAgState(zeros((2,2),Vector{Float64}())))
end

function Agent(id,state)
    #:blue,phase,[],0,1,id,zeros((2,2))
    Agent(id,(rand(1:10),rand(1:10)),state)
end
