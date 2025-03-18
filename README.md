# power-system-resilience
A power system resilience model, simulating the power system outage and restoration processes during an extreme weather event. Based on MATPOWER's power system simulation library and the AC-CFM cascading failure simulator [1].

# Licensing & Citing
This software is open source under the GNU GPLv3 license. All usage, re-production, and re-distribution of this software must respect the terms and conditions of this license.

We request that publications deriving from the use of this power system resilience model explicitly acknowledge that fact by citing the following publication:

A. Gerkis and X. Wang, “Efficient probabilistic assessment of power system resilience using the polynomial chaos expansion method with enhanced stability,” 2025.

# Introduction
The power system resilience model simulates a power system's response to an extreme weather event. This response is divided into three distinct stages: disturbance, when the system is experiencing damage due to an extreme event; outage, the period after the event before restoration begins; and restoration, when the system is being repaired [2]. The resilience trapezoid, Figure 1, depicts these three stages by plotting the system's performance, measured through some "performance indicator", versus time.

![The Resilience Trapezoid](https://github.com/user-attachments/assets/206616fb-8f80-4ef9-b404-3f99a31ef896)
*The resilience trapezoid model of a resilience event.*

The power system resilience model simulates these three stages independently to model the system's complete response to an extreme weather event.

# Model Structure
# Disturbance Modelling










# References
[1]: AC-CFM
[2]: The IEEE task-force paper
