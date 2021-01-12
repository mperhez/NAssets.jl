# network-fleet-abm

This code base is using the Julia Language and [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/)
to make a reproducible scientific project named
> network-fleet-abm

It is authored by mperhez.

To (locally) reproduce this project, do the following:

0. Download this code base. Notice that raw data are typically not included in the
   git-history and may need to be downloaded independently.
1. Open a Julia console and do:
   ```
   julia> using Pkg
   julia> Pkg.activate("path/to/this/project")
   julia> Pkg.instantiate()
   ```

This will install all necessary packages for you to be able to run the scripts and
everything should work out of the box.


# ideas

* Each agent has a function that has a match-case structure 
* The state is probabilistic, there are facts that have more probability than others, e.g. with a normal distribution
* properties of state are linked like a bayes tree



# support

* [Weibull distribution](https://youtu.be/ustgf9D7d5Q?t=894)