---
title: 'NAssets.jl: A Package For Simulation Of Networked Assets Dynamics '
tags:
  - network dynamics
  - agent-based simulation
  - julia
authors:
  - name: Marco Perez Hernandez
    orcid: 0000-0001-9697-3672
    corresponding: true
    affiliation: 1
  - name: Ajith Kumar Parlikad
    orcid: 0000-0001-6214-1739
    affiliation: 2
  - name: Manuel Herrera
    orcid: 0000-0001-9662-0017
    affiliation: 2
  - name: Alena Puchkova
    orcid: TBD
    affiliation: 2
affiliations:
 - name: University of The West of England (UWE)
   index: 1
 - name: University of Cambridge
   index: 2
date: 29 September 2022
bibliography: paper.bib

---

# Summary

NAssets.jl is a Julia package that provides an environment for simulation of assets dynamics in a network. NAssets.jl enables simulation of network management and operation including traffic routing, asset's condition deterioration, disruption handling and maintenance scheduling, among others. A NAssets.jl simulation is built from an underlying network of assets and an agent-based control system. Apart from centralised single-agent control systems, NAssets.jl enables to set multi-agent control networks where agents cooperate for the distributed management of the underlying network of assets. NAssets.jl is built on top of Agents.jl[@Vahdati2019] and uses widely the the Julia Graphs ecosystem [@JGraphs], among other packages.


# Statement of need

The simulation of asset condition and performance dynamics has been widely used by engineering researchers and practitioners as a tool for evaluating prediction algorithms, maintenance strategies and other asset management approaches [TBC]. However, there are three key challenges that slow down the evaluation of these approaches: 1) lack of open source asset management reusable simulation tools, 2) individual asset-centred analysis and 3) weak integration of asset's context-specific dynamics. 
These challenges are evident as most of the simulation environments used so far for asset management evaluation are ad hoc implementations, focused on the challenges being addressed in given work [TBC].

NAssets.jl can be used as a boilerplate for simulation of individual but specially networked assets dynamics. This way researchers and practitioners can define the characteristics and condition behaviours of a fleet or portfolio of assets where, by default, links among them represent operational flows. Then network-wide behaviour can be analysed for a given network configuration and operational patterns of the individual assets. 
NAssets.jl is contextualised in nationwide telecom networks, integrating a traffic flow management and routing based on Openflow[TBC]. However, asset condition, control and network elements and behaviours are general and can be exploited to analyse networked-assets in different contexts. 

<!-- normally assets are studied individually or in reduced groups, isolating other perspectives than have the potential to influence management decisions. Likewise, evaluation of approaches  -->
<!-- Julia is a young language with a neat intuitive syntax, a solid performance and promising library ecosystem. -->

## Examples

TBC

```julia
using NAssets

```

# Acknowledgments

This work is supported by the Engineering and Physical Sciences Research Council (EPSRC) through the BT Prosperity Partnership Project: Next Generation Converged Digital Infrastructure under Grant EP/R004935/1. We also acknowledge the support of the University of the West of England (UWE) under the Vice-Cancellor Early Career Researcher award no. UCSC0082. 

# References