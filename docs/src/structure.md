# NAssets.jl Structure

* ``core``: structs and main graph functions
* ``ctl``: functions used by the control agent(s)
* ``agent_control.jl``: operation of control agent and communication between agents
* ``queries_basic/multiple.jl`` : queries used by the control agents to find paths.
* ``eve``: functions for triggering artificial events on the asset network, for example random failures.
* ``model``: Main ABM functions including agent and model steps.
* ``ntw``: Network Protocol Functions including minimal implementation of flows and actions based on OpenFlow.
* ``phy``: Physical model for asset deterioration and maintenance.
* ``utils``: General util functions used throughout.


Back to [index](index.md)