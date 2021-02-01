#Core structures
include("model/netManStructs.jl")
include("model/of_switch.jl")
include("model/of_controller.jl")

#Main Functions
include("model/netManFunctions.jl")

#Agents.jl function implementation for this model
include("model/netManModel.jl")

#end # module
