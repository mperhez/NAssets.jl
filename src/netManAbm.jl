# time-to-event functions
include("model/tte_functions.jl")
#Core structures
include("model/netManStructs.jl")
include("model/of_switch.jl")
include("model/of_control.jl")
include("model/agent_control.jl")

include("model/physical_model.jl")

include("model/network_model.jl")
include("model/geo_model.jl")

#Main Functions
include("model/netManFunctions.jl")

#Plotting functions
include("utils/plotting_functions.jl")

#Agents.jl function implementation for this model
include("model/netManModel.jl")

#Basic queries
#include("model/queries_basic.jl")
#Multiple queries
include("model/queries_multiple.jl")

#end # module
