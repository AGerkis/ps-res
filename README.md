# power-system-resilience
A power system resilience model, simulating the power system outage and restoration processes during an extreme weather event. Based on MATPOWER's power system simulation library [1] and the AC-CFM cascading failure simulator [2].

# Licensing & Citing
This software is open source under the GNU GPLv3 license. All usage, re-production, and re-distribution of this software must respect the terms and conditions of this license.

We request that publications deriving from the use of this power system resilience model explicitly acknowledge that fact by citing the following publication:

A. Gerkis and X. Wang, “Efficient probabilistic assessment of power system resilience using the polynomial chaos expansion method with enhanced stability,” 2025.

# Introduction
The power system resilience model simulates a power system's response to an extreme weather event. This response is divided into three distinct stages: disturbance, when the system is experiencing damage due to an extreme event; outage, the period after the event before restoration begins; and restoration, when the system is being repaired [3]. The resilience trapezoid, Figure 1, depicts these three stages by plotting the system's performance, measured through some "performance indicator", versus time.

![The Resilience Trapezoid](https://github.com/user-attachments/assets/206616fb-8f80-4ef9-b404-3f99a31ef896)
<p align=center>*The resilience trapezoid model of a resilience event.*

The power system resilience model simulates these three stages independently to model the system's complete response to an extreme weather event.

# Model Structure
## Disturbance Modelling
During the disturbance stage, a power system's components will be damaged by the extreme weather conditions. The disconnection of damaged components (referred to as initial contingencies) can trigger a cascade of failures throughout the network, causing widespread outages. It is these cascading failures that cause the extreme blackouts associated with weather events. The disturbance stage thus simulates these cascading failures to model blackouts in the network.

To simulate the system's response the extreme event is discretized into hourly time-steps at which initial contingencies occur. At each time-step the initial contingencies are disconnected from the network and the AC-CFM model [2] is used to compute the resulting cascades and system state. This process is repeated at every time-step to determine the system's state at the end of the disturbance stage.

## Outage Modelling
In the outage stage the extreme weather event has passed, so no further initial contingencies occur, but the repair and restoration of damaged components has not yet begun. The system's state is thus approximately constant, varying only to natural changes in demand.

The power system resilience model simulates the outage stage with a constant length, during which the system's state does not change from its state after the disturbance stage.

## Restoration Modelling
During the restoration stage the power system's damaged components are repaired and the network is reconnected, eventually restoring demand to its pre-disturbance levels.

The restoration stage is modelled by determining the repair time for each damaged component. These repair times are used as the time-steps for the restoration model (i.e., the system is assumed to change only after a component is repaired). At each time-step the repaired component(s) is reconnected to the system, as are any neighbouring components which were disconnected during the disturbance stage. The optimal power-flow algorithm is used to compute the system's state, which is passed to the next time-step. If a convergent system state does not exist then the neighbouring components are disconnected from the network. In either case, the simulation is advanced to the next time-step. This process is completed until all components have been repaired and reconnected and the system is restored to its pre-disturbance state.

## Model Inputs & Parameters
The primary inputs to the PSres model are the component failure times during an extreme event and the repair times. These are represented as a vector, whose entries represent the time (measured from the event's start) when the component fails. Extreme storms are typically modelled as affecting only a subsection of the complete network, so this input vector generally represents a subset of network components. We adopt the notation that a component which does not fail during an event is assigned a failure time of zero. The repair times are also represented by a vector, whose entries represent the time (measured from the restoration period's start) when the component is repaired. This vector should be the same size as the vector of component failure times. As in the component failure vector, a component which does not fail (and thus does not need to be repaired) is assigned a repair time of zero.

Inputs can be specified in one of two ways: as explicit model inputs, where the user selects the failure and repair times, or as implicit model inputs, where the user provides data from which repair times and recovery times are calculated. In the implicit formulation the user must provide a fragility curve and a vector representing the repair time distribution. The fragility curve models a component's failure probability as a function of the weather state [5] and is passed to the model as a series of x values (representing weather state) and y values (representing weather state). For more details on specifying fragility curves see **Specifying Fragility Curves**. In the implicit PSres model formulation component failures and repair times are determined randomly at runtime. Component failures are determined by comparing failure probability to the weather state and repair times are determined by randomly sampling the provided distribution. Thus, the implicit model formulation is stochastic; the model output will be different on consecutive runs, even if the inputs remain constant. By contrast, the PSres model's explicit formulation is deterministic; it will always provide the same output when given the same input. 


Other inputs...
- Num Workers
- Network
- Event Model

Parameters...


## Model Outputs
The PSres model outputs the complete system state in the MATPOWER case format...

The model also calculates several resilience indicators and includes these in the output. 


## Specifying Fragility Curves

# References
[1]: R. D. Zimmerman, C. E. Murillo-Sanchez, and R. J. Thomas, “MATPOWER: Steady-State Operations, Planning and Analysis Tools for Power Systems Research and Education,” Power Systems, IEEE Transactions on, vol. 26, no. 1, pp. 12–19, Feb. 2011.
[2]: AC-CFM M. Noebels, R. Preece, and M. Panteli, “Ac cascading failure model for resilience analysis in power networks,” IEEE Systems Journal, vol. 16, no. 1, pp. 374–385, March 2022.
[3]: A. M. Stankovi´c, K. L. Tomsovic, F. De Caro, M. Braun, J. H. Chow, N. Cukalevski et al., “Methods for analysis and quantification of power system resilience,” IEEE Transactions on Power Systems, vol. 38, no. 5, pp. 4774–4787, Sept. 2023.
[4]: S. Marelli, C. Lamas, K. Konakli, C. Mylonas, P. Wiederkehr, and B. Sudret, “UQLab user manual – Sensitivity analysis,” Chair of Risk, Safety and Uncertainty Quantification, ETH Zurich, Switzerland, Tech. Rep., 2024, report UQLab-V2.1-106.
[5]: M. Panteli, P. Mancarella, D. N. Trakas, E. Kyriakides, and N. D. Hatziargyriou, “Metrics and quantification of operational and infrastructure resilience in power systems,” IEEE Transactions on Power Systems, vol. 32, no. 6, pp. 4732–4742, Nov. 2017.
