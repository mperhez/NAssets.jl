#Core structures
include("model/netManStructs.jl")
include("model/of_switch.jl")
include("model/of_controller.jl")

include("model/physical_model.jl")

#Main Functions
include("model/netManFunctions.jl")

# time-to-event functions
include("model/tte_functions.jl")

#Agents.jl function implementation for this model
include("model/netManModel.jl")

#end # module
