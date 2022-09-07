# Beginner Example

The src code of this example is available in the examples folder.


Every simulation in NAssets requires a configuration object. This is Julia `Tuple` object:

```
bcfg = (
        ntw_topo = 2,
        size = 5,
        ctl_model = 1, 
        n_steps = 80, 
        traffic_dist_params = [1.0, 0.05], 
        ntw_services = [(3, 5), (1, 4)] 
        )
```


