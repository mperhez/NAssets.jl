<style>
table th:first-of-type {
    width: 15%;
}
table th:nth-of-type(2) {
    width: 20%;
}
table th:nth-of-type(3) {
    width: 10%;
}
table th:nth-of-type(4) {
    width: 55%;
}
</style>

# `NAssets` Simulation Parameters



## General


| Param | Domain | Default | Description |
|-------|------|----|--------------|
|`ntw_topo`| `0, (2-7)`| `2` | Used to define the topology of the underlying network of assets. This should be an integer linked to the `GraphModel` enum as follows: `2`. RING, `3`. COMPLETE, `4`. GRID, `5`. STAR, `6`. BA_RANDOM, `7`. WS_RANDOM, `0`. CUSTOM (The network and its topology is specified as an *adjacency matrix* in the CSV file whose name is indicated in the param: `ntw_csv_adj_matrix`)| 
|`size`| `Int`| `5` | When the network is randomly generated, it indicates the number of nodes.|
|`seed`| `Int > 0` | `N/A` | Random seed to use. 
|`n_steps`| `Int > 0` | `20` | Steps to run the simulation for. |
|`ctl_model`| `(0-7)` | `1` | Topology to use for the control network from `GraphModel` enum. Same values as specified for `ntw_topo`, plus  `1`: indicates centralised topology (single control agent). |
| `k`| `(0. - 1.)` | `1` | If random topo for underlying network (`ntw_topo` != 0). `K` parameter to use in randomly generated underlying networks |
| `B` | `(0. - 1.)` | `0.5` | If random topo for underlying network (`ntw_topo` != 0). `B` parameter to use in randomly generated underlying networks. |
| `ctl_k` | `(0. - 1.)` | `1` | If random topo for control network (`ctl_model` != 0). `K` parameter to use in randomly generated control networks. |
| `ctl_B` | `(0. - 1.)` | `0.5` | If random topo for control network (`ctl_model` != 0). `B` parameter to use in randomly generated control networks. |
| `ntw_csv_adj_matrix` | `String` | `N/A` | If custom topo for underlying network (`ntw_topo` == 0), it sets the location of the CSV file containing the *adjacency matrix* for the underlying network topology. | 
| `ctl_csv_adj_matrix` | `String` | `N/A` | If custom topo for control network (`ctl_model` == 0), it sets the location of the CSV file containing the *adjacency matrix* for the control network topology. |
| `benchmark` | `Boolean` | `false`| It activates benchmarks [BenchmarkTools.jl](https://juliaci.github.io/BenchmarkTools.jl/stable/) for the run. Simulation takes longer when activated.
| `out_to_file` | `Boolean` | `false` | Sent sim output to a file. |
| `data_dir` | `String` | `N/A` | When `out_to_file` == `true`, it sets the output data dir. |
|---|

## Asset Maintenance Params 

| Param | Domain | Default | Description |
|-------|------|-----------|----|
| `deterioration` | `NTuple` | `[ (rul,t,a) -> rul - a 0.0 ] ` | Deterioration parameters for network assets. This parameter is used by the `deteriorate!` function in the `physical_model` module. This is a `NTuple` where first element is a `function` and the other elements are the values of any constant used. The `function` has at least three arguments, current `remaining useful life` of the asset (`rul`) and current tick (`t`), which are taken from the simulation model. The other parameter `a` is an arbitrary constant, whose value is defined as the second element of the `NTuple`. Additional arguments can be added to the `function` and their values specified as additional elements of the `NTuple`. 
| `prediction` | `NTuple` | `[ (rul,t,a) -> rul - a 0.0 ]` | Function used to predict rul of the assets. Default equal to deterioration. |
| `mnt_policy` | `Int` | `0` | Maintenance policy used in the simulation. `0`: Corrective, `1`: Preventive, `2`: Custom/Optimal |
| `mnt_wc_duration` | `Int > 0` | `0` | Worst case duration of the maintenance operations (ticks) |
| `mnt_bc_duration` | `Int > 0` | Best case duration of the maintenance operations (ticks) |
| `mnt_wc_cost` | `Float > 0.` | `0` | Worst case costs of maintenance operations (££). |
| `mnt_bc_cost` | `Float > 0.` | `0` | Best case costs of maintenance operations (££). | 
| `deterioration_threshold` | `(0. - 1.)` | `0.1` | Threshold for deterioration of assets i.e. assets will drop when RUL reaches this. |

## Underlying Network & Traffic Params

| Param | Domain/Type | Default | Description |
|-------|------|-----------|----|
| `ntw_services` | `Vector[Tuple(Int,Int)]` | `[]` | List of pairs of nodes of the underlying network where the traffic is flowing. e.g. `[(3,7),(8,2)]` indicates that 2 services are running in the underlying network. First service implies there is traffic flowing between assets `3` and `7`. Second service, traffic flowing between `8` and `2`. |
| `traffic_dist_params` | `Vector[Float,Float]` | `[1.0, 0.05]` | Distribution params *(mean, std)* for traffic generation. 
| `traffic_packets` | `Int > 0` | `400` | Magnitude No. of packets for traffic generation. |
| `link_capacity` | `Int > 0` | `400` | Link Capacity/Bandwidth per tick (Packets) |
| `interval_tpt` | `Int > 0` | `10` | Ticks used for throughput calculation. |
| `pkt_size` | `Int > 0` | `1` | Packet size for throughput calculations. |
| `pkt_per_tick` | `Int > 0` | `2000` | Default packet processing capacity for all nodes. |
| `capacity_factor` | `Float > 0.` | `1.2` | default capacity factor of packets processed per tick | (`.2` extra is to have always room for management messages.) This Factor is used to have nodes with different processing capacities. |
| `max_queue_ne` | `Int > 0` | `300` | Queue size for each node of the underlying network (Packets) |

## Control params

| Param | Domain/Type | Default | Description |
|-------|------|-----------|----|
| `prob_random_walks` | `Float > 0.` | `.` | For distributed control. Probability of neighbour nodes to propagate query msgs when discovering/learning underlying network. |
| `clear_cache_graph_freq` | `Int > 0` | `50` | frequency for clearing cache of learned graphs by control agents to avoid large outdated graphs. |
| `max_msg_live` | `Int > 0` | `5` | Max ticks a control message is live in the simulation. |
| `ofmsg_reattempt` | `Int > 0` | `10` | Frequency for re-attempting un-responded OpenFlow-like messages |
| `max_cache_paths` | `Int > 0` | `2` | Max quantity of paths to store in the control agent cache. |

## Event Simulation

| Param | Domain/Type | Default | Description |
|-------|------|-----------|----|
| `drop_proportion` | `Float >= 0.` | 0. | Proportion of nodes that will drop from the network |
| `drop_stabilisation` | `Int > 0` | `10` | ticks to wait at the end of simulation after the last node has been dropped. |

## Further customisation

| Param | Domain/Type | Default | Description |
|-------|------|-----------|----|
| `init_sne_params` | `(ids=[],ruls=[], deterioration=[],capacity_factor=[],mnt_policy=[],prediction=[])`| `N/A` | List of node ids and their specific initial parameters. e.g. `(ids=[15,19],ruls=[1,0.7],deterioration=[0.2,0.001],capacity_factor=[1.2,5])`. This indicates that for node `15`, the starting `RUL` (Remaining Useful Life) will be `1.`, the deterioration parameter is `0.2` and the packet capacity is `1.2x` (pkt_per_tick) . Likewise, for node `19`, starting `RUL` is `0.7`, deterioration `0.001` and capacity factor `5x` (pkt_per_tick). |
| `init_link_params` | `(ids=[],capacities=[])` | `N/A` | List of links (node pairs) and their specific initial  parameters. e.g. `(ids=[(15,17),(8,9)],capacities=[200,400])`. Setting a capacity of `200` packets per tick for link `15-17` and `400` packets per tick for link `8-9`.
      