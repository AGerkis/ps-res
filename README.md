# PSres
PSres is a power system resilience model, simulating the power system outage and restoration processes during an extreme weather event. It is based on MATPOWER's power system simulation library [1] and the AC-CFM cascading failure simulator [2].

# Licensing & Citing
This software is open source under the GNU GPLv3 license. All usage, re-production, and re-distribution of this software must respect the terms and conditions of this license.

We request that publications deriving from the use of the PSres model explicitly acknowledge that fact by citing the following publication:

A. Gerkis and X. Wang, “Efficient probabilistic assessment of power system resilience using the polynomial chaos expansion method with enhanced stability,” in 2025 IEEE Power & Energy Society General Meeting (PESGM), Austin, TX, July 2025.

# Introduction
PSres' primary goal is to simulate a power system's response to an extreme weather event. From this response the user can then quantify the system's resilience through the application of resilience indicators and metrics.

To perform this simulation, the power system's response is divided into three distinct stages: disturbance, when the system is experiencing damage due to an extreme event; outage, the period after the event before restoration begins; and restoration, when the system is being repaired [3]. The resilience trapezoid, Figure 1, depicts these three stages by plotting the system's performance, measured through some "performance indicator", versus time.

<p align="center" width="100%">
<img src="https://github.com/user-attachments/assets/206616fb-8f80-4ef9-b404-3f99a31ef896" alt="Resilience Trapezoid" width="500">
</p>
<p align="center"><i>The resilience trapezoid model of a resilience event.</i>
</p>
    
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

The PSres model's parameters and inputs are passed in 7 input structures:\
`ac_cfm_settings`: Contains the settings to use when calling AC-CFM.\
`network`: The power system which is being modelled.\
`recovery_params`: The system's recovery parameters.\
`resilience_event`: The resilience event's parameters.\
`analysis_params`: Parameters to use when computing resilience metrics.\
`generation`: Parameters describing time-varying generation.
`load`: Parameters describing time-varying load.

The `analysis_params` structure contains fields used when computing resilience metrics:\
`q`: The quantile after which recovery is considered to be complete. [6]

The `generation` and `load` structures allow for the definition of time-varying loads. These can be deterministic, following a specified load/generation pattern, or random, with the load/generation at each time-step randomly generated from a probability distribution. For more details see the documentation of `psres`.

For details on the remaining input structures see Examples 1 and 2.

## Model Outputs
The PSres model outputs four different structures:
```
[state, resilience_indicators, resilience_metrics, sim_info] = psres(ac_cfm_settings, network, recovery_params, resilience_event, analysis_params, generation, load);
```
PSres's primary output is the system state (in the MATPOWER case format) at the end of each stage. This allows a large degree of flexibility in the indicators and metrics used to quantify resilience, giving the user access to any power system variables computed by the MATPOWER solvers. The system state can be found in the `state` output structure.\
`state.disturbance`: The system's state after the disturbance stage.\
`state.outage`: The system's state after the outage stage.\
`state.restoration`: The system's state after the restoration stage.

The model also calculates several resilience indicators at a higher fidelity and includes these in the output. These indicators are computed at each PSres model time-step (compared to the system state, which is only output at the end of each stage). They can be found in the `resilience_indicators` output structure. Currently the supported indicators are:\
'if_rel.tl_dc`: The number of transmission lines disconnected from the system. [Number of Transmission Lines]\
'if_rel.load_dc`: The number of buses disconnected from the system. [Number of Buses]\
'if_rel.gen_dc`: The number of generators disconnected from the system. [Number of Generators]\
`op_rel.load_served`: The total demand served by the system. [MW]\
`op_rel.gen_online`: The total generation capacity connected to the system. [MW]\
The total number of components damaged by the event (i.e. those specified as inputs) and disconnected (due to cascading failures) are specified in variables `n_tl_dc`, `n_load_dmg`, `n_bus_dc`, `n_load_dmg`, `n_gen_dc`, and `n_gen_dmg`. The PSres model's time-steps corresponding to the resilience indicator measurements are saved in `resilience_indicators.t.tot`.

Finally, the model applies the $\Phi\Lambda E\Pi$ metrics, proposed by Panteli et al. [5] to quantify the system's resilience through the aforementioned indicators. These are included in the `resilience_metrics` output structure.

General simulation information is included in the '''sim_info''' output structure.\
`n_contingencies`: The total number of components damaged by the extreme event.\
`n_cascades`: The total number of components disconnected from the network due to cascading failures.\
`contingencies`: The component failure times.\
`recovery_times`: The component repair times.

# Examples
To showcase application of the resilience model two examples are detailed below. The first example deals with the explicit input formulation, while the second details the implicit input formulation.

## Default Datasets
Three default datasets are provided for use in the example resilience models:\
`frag_curve.mat`: Contains transmission line fragility curves (specified as a vector of weather states and corresponding failure probabilities) computed using outage data in the BPA power system [7] and corresponding weather data [8].\
'recovery_data.mat': Contains transmission line repair time data from the BPA power system [7].\
'wind_profiles.mat': Contains six different extreme windstorm profiles, corresponding to major storms in the Pacific North West.

## Example 1: Resilience Quantification with Explicit Inputs
In this example we construct and execute the PSres model using the explicit input formulation. This model follows the code in `ex1_ps_res.m`.

First define the default simulation settings and the resilience output enumeration
```
P = ps_resilience_params('default');
output = [1 1; 1 2; 1 3; 1 4; 1 5;
          2 1; 2 2; 2 3; 2 4; 2 5];
```
Then define the network to be simulated (in this case the IEEE 39-Bus network) and extract some useful parameters
```
network = initialize_network(case39); % Network for analysis
n_comp = [length(network.branch(:,1)); length(network.bus(:,1)); length(network.gen(:,1))];
```
We then specify the event model, first loading the weather profile containing the event data
```
fname_env_state = "wind_profiles.mat";
profile_name = "wind_20181220_20181220";
profiles = load(fname_env_state, 'output').output;
```
The curve defining weather state versus time is then specified and parameters are extracted
```
env_state = profiles.(profile_name).max_intensity_profile';
t_event_end = length(env_state);
t_step = 1;
```
Then, the components being affected by the weather event must be specified. In this case the storm is assumed to only damage transmission lines 19, 22, 23, 24, 25, and 26.
```
active_set = [19, 22, 23, 24, 25, 26;
    "branch", "branch", "branch", "branch", "branch", "branch"];
```
We then specify the number of workers repairing each component. The first array element represents transmission lines, the second buses, and the third generators.
```
num_workers = [2, 2, 1]; 
```


We can now define the model inputs, first specifying the component failure times at each transmission line. The array is initialized with all zeros, and the components experiencing a failure are then specified.
```
contingencies = struct("branches", zeros(1, n_comp(1)), "busses", zeros(1, n_comp(2)), "gens", zeros(1, n_comp(3)));
contingencies.branches(str2double(active_set(1, :))) = [12 12 0 4 22 19];
```
The input mode is then specified as explicit
```
event_mode = 'Explicit';
```
We can then specify the repair times analogously
```
recovery_times = struct("branches", zeros(1, n_comp(1)), "busses", zeros(1, n_comp(2)), "gens", zeros(1, n_comp(3)));
recovery_times.branches(str2double(active_set(1, :))) = [3 2 0 9 7 1];
recovery_mode = 'Explicit';
```
The various event parameters are then compiled into structures representing the weather event and component recovery
```
recovery_params = struct("n_workers", num_workers, 'recovery_times', recovery_times, 'Mode', recovery_mode);
resilience_event = struct("contingencies", contingencies, "state", env_state, "active", active_set, "length", t_event_end, "step", t_step, 'Mode', event_mode); % Compile all event parameters
```
And finally, the resilience model is run by calling `psres`
```
[state, ri, rm, info] = psres(P.ac_cfm_settings, network, recovery_params, resilience_event, P.analysis_params, '', '');
```
Model outputs can then be plotted (for resilience indicators) and printed to the console (for resilience metrics) 
```
ps_print(rm, P.Output);
ps_plot(ri, P.Output);
```
For this example, the metric output should appear as follows
<p align="center" width="100%">
<img src="https://github.com/user-attachments/assets/4838ddd6-78ce-4fcc-b1fe-918db48b53dc" alt="Resilience Metric Output" width="300">
</p>
and the resilience indicator plots should match the following
<p align="center" width="100%">
<img src="https://github.com/user-attachments/assets/c7492726-c1cb-4a4a-9f5b-e178ffe9b11c" alt="Load Served Plot" width="400">
<img src="https://github.com/user-attachments/assets/3787a2fd-c2e0-4bf5-90cc-885da18c8028" alt="Transmission Lines Disconnected Plot" width="400">
</p>

## Example 2: Resilience Quantification with Implicit Inputs
In this example the PSres model is constructed and ran using the implicit input formulation. First, follow the model initialization process in Example 1, stopping before the model inputs are defined.

The fragility curves can then be loaded from the default datasets
```
fname_f_curve = "frag_curve.mat";
f_curve_data = load(fname_f_curve, 'failure_curve');
```
And can then be assigned to each component class (branch, bus, and generator). The $-1$ term in the second and third positions indicates that no failures occur for these components.
```
f_curve_data = {[f_curve_data.failure_curve.x; f_curve_data.failure_curve.y], ... 
    [f_curve_data.failure_curve.x; -1*ones(1, length(f_curve_data.failure_curve.x))],... 
    [f_curve_data.failure_curve.x; -1*ones(1, length(f_curve_data.failure_curve.x))]}; 
```
The fragility curves can then be assigned to a structure using the `assign_failure_curves` function
```
failure_curves = struct;
[failure_curves.branches, failure_curves.busses, failure_curves.gens] = assign_failure_curves(f_curve_data, n_comp);
```
And the input mode should be specified
```
event.mode = 'Implicit';
```
Repair times can be specified by loading the default dataset and calling the `assign_rec_data` function, then specifying the input mode
```
fname_rec_data = "recovery_data";
rec_data = assign_rec_data(fname_rec_data, "", "");
recovery_mode = 'Implicit';
```
Finally, the inputs can be placed into their respective structures and the psres model can be called
```
recovery_params = struct("n_workers", num_workers, 'branch_recovery_samples', rec_data.branch_recovery_samples, 'bus_recovery_samples', rec_data.bus_recovery_samples, 'gen_recovery_samples', rec_data.gen_recovery_samples, 'Mode', recovery_mode);
resilience_event = struct("failure_curves", failure_curves, "state", env_state, "active", active_set, "length", t_event_end, "step", t_step, 'Mode', event_mode); % Compile all event parameters

[state, ri, rm, info] = psres(P.ac_cfm_settings, network, recovery_params, resilience_event, P.analysis_params, '', '');
```

# Specifying Fragility Curves
Fragility curves can be specified directly, as an array of weather states and the corresponding failure components, or as a parametric distribution with its corresponding parameters. Curves may also be specified per component or en masse for the entire system. See the documentation of `assign_failure_curves`` for details.

# Final Thoughts
Please note that this codebase is not actively maintained. For more information on the resilience model, and resilience modelling in general see [2], [3], [5], and [9]. Good luck and happy modelling!

# References
[1] R. D. Zimmerman, C. E. Murillo-Sanchez, and R. J. Thomas, “MATPOWER: Steady-State Operations, Planning and Analysis Tools for Power Systems Research and Education,” Power Systems, IEEE Transactions on, vol. 26, no. 1, pp. 12–19, Feb. 2011.\
[2] AC-CFM M. Noebels, R. Preece, and M. Panteli, “Ac cascading failure model for resilience analysis in power networks,” IEEE Systems Journal, vol. 16, no. 1, pp. 374–385, March 2022.\
[3] A. M. Stankovi´c, K. L. Tomsovic, F. De Caro, M. Braun, J. H. Chow, N. Cukalevski et al., “Methods for analysis and quantification of power system resilience,” IEEE Transactions on Power Systems, vol. 38, no. 5, pp. 4774–4787, Sept. 2023.\
[4] S. Marelli, C. Lamas, K. Konakli, C. Mylonas, P. Wiederkehr, and B. Sudret, “UQLab user manual – Sensitivity analysis,” Chair of Risk, Safety and Uncertainty Quantification, ETH Zurich, Switzerland, Tech. Rep., 2024, report UQLab-V2.1-106.\
[5] M. Panteli, P. Mancarella, D. N. Trakas, E. Kyriakides, and N. D. Hatziargyriou, “Metrics and quantification of operational and infrastructure resilience in power systems,” IEEE Transactions on Power Systems, vol. 32, no. 6, pp. 4732–4742, Nov. 2017.\
[6] I. Dobson and S. Ekisheva, “How long is a resilience event in a transmission system?: Metrics and models driven by utility data,” IEEE Transactions on Power Systems, pp. 1–12, 2023.\
[7] Bonneville Power Administration, “Reliability & outage reports,” [Online]. Accessed: 2023-11-28, Available: https://transmission.bpa.gov/Business/Operations/Outages/.\
[8] Global Modeling and Assimilation Office (GMAO), “MERRA-2 inst1 2d asm Nx: 2d,1-Hourly,Instantaneous,Single-Level,Assimilation,Single-Level Diagnostics V5.12.4,” 2015, greenbelt,MD, USA, Goddard Earth Sciences Data and Information ServicesCenter (GES DISC). Accessed: 2023-12-18.\
[9] A. Gerkis and X. Wang, “Efficient probabilistic assessment of power system resilience using the polynomial chaos expansion method with enhanced stability,” 2025.
