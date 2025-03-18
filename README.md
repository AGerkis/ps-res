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

## Model Inputs

## Model Outputs

# References
[1]: R. D. Zimmerman, C. E. Murillo-Sanchez, and R. J. Thomas, “MATPOWER: Steady-State Operations, Planning and Analysis Tools for Power Systems Research and Education,” Power Systems, IEEE Transactions on, vol. 26, no. 1, pp. 12–19, Feb. 2011.
[2]: AC-CFM M. Noebels, R. Preece, and M. Panteli, “Ac cascading failure model for resilience analysis in power networks,” IEEE Systems Journal, vol. 16, no. 1, pp. 374–385, March 2022.
[3]: A. M. Stankovi´c, K. L. Tomsovic, F. De Caro, M. Braun, J. H. Chow, N. Cukalevski et al., “Methods for analysis and quantification of power system resilience,” IEEE Transactions on Power Systems, vol. 38, no. 5, pp. 4774–4787, Sept. 2023.
[4]: S. Marelli, C. Lamas, K. Konakli, C. Mylonas, P. Wiederkehr, and B. Sudret, “UQLab user manual – Sensitivity analysis,” Chair of Risk, Safety and Uncertainty Quantification, ETH Zurich, Switzerland, Tech. Rep., 2024, report UQLab-V2.1-106.
