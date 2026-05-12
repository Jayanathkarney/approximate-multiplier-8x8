# approximate-multiplier-8x8
Mode-configurable 3-stage pipelined 8x8 approximate multiplier with partial-product isolation and Wallace-tree compression — DVLSI Course Project, IISc

# Mode-Configurable 3-Stage Pipelined 8×8 Approximate Multiplier
### With Partial-Product Isolation and Wallace-Tree Compression

<br>

> **Course:** Digital VLSI Design (DVLSI) — Course Project
> **Institution:** Indian Institute of Science (IISc), Bangalore
> **Department:** Electronic Systems Engineering — M.Tech (EPD)
> **Authors:** Karney Jayanath (SR No. 26831) · Shreevathsa K S
> **Course Instructor:** Prof. Viveka K R

<br>

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Motivation](#2-motivation)
3. [Architecture](#3-architecture)
   - [Top-Level Block Diagram](#31-top-level-block-diagram)
   - [Stage 1 — Input Register and Mode Decoder](#32-stage-1--input-register-and-mode-decoder)
   - [Stage 2 — Partial Product Generator and Wallace Tree](#33-stage-2--partial-product-generator-and-wallace-tree)
   - [Stage 3 — Brent-Kung Prefix Adder](#34-stage-3--brent-kung-prefix-adder)
4. [MODE Configuration and Approximation Control](#4-mode-configuration-and-approximation-control)
5. [Operand Isolation and Glitch Prevention](#5-operand-isolation-and-glitch-prevention)
6. [Verification Methodology](#6-verification-methodology)
   - [Transistor-Level Verification](#61-transistor-level-verification)
   - [RTL Simulation and VCD Analysis](#62-rtl-simulation-and-vcd-analysis)
7. [Timing Characterization](#7-timing-characterization)
8. [Power and Energy Analysis](#8-power-and-energy-analysis)
9. [Accuracy and Error Metrics](#9-accuracy-and-error-metrics)
10. [Energy-Delay Product (EDP)](#10-energy-delay-product-edp)
11. [Pareto Frontier Analysis](#11-pareto-frontier-analysis)
12. [Repository Structure](#12-repository-structure)
13. [Tools Used](#13-tools-used)
14. [How to Simulate (RTL)](#14-how-to-simulate-rtl)
15. [Key Takeaways and Learning Outcomes](#15-key-takeaways-and-learning-outcomes)
16. [Future Work](#16-future-work)
17. [References](#17-references)
18. [License](#18-license)

<br>

---

## 1. Project Overview

This project presents the complete design, implementation, and parasitic-aware characterization of a **mode-configurable three-stage pipelined 8×8 unsigned approximate multiplier**. The design was developed in **Cadence Virtuoso** as part of the Digital VLSI Design (DVLSI) course at IISc Bangalore.

The multiplier accepts two 8-bit unsigned operands and produces a 16-bit unsigned product. What makes it distinct from a standard multiplier is the **5-bit MODE configuration word** that allows real-time, run-time control over arithmetic accuracy. Depending on which MODE is selected, specific partial-product rows are selectively enabled or disabled before they enter the compression network. This directly and predictably reduces dynamic switching activity inside the Wallace tree, resulting in measurable power and energy savings.

The key innovation is not just approximation — it is **controlled and safe approximation**. Operand-isolation cells ensure that disabled rows are fully clamped to logic zero, preventing floating internal nodes and glitch propagation into deeper compressor stages. This makes the design robust even under parasitic extraction (post-PEX), where unwanted RC coupling could otherwise corrupt logic transitions.

The complete characterization flow covers functional verification, timing analysis, input-capacitance compliance, post-PEX simulation, energy measurement, and accuracy evaluation. All results are reported both before and after parasitic extraction to give a realistic picture of the design's behavior in a fabricated circuit.

<br>

---

## 2. Motivation

Modern edge processors, IoT devices, and neural network accelerators operate under extremely tight energy budgets. The arithmetic units inside these systems — especially multipliers — are among the most power-hungry blocks. At the same time, many of these applications are inherently error-tolerant. Tasks like image filtering, convolutional neural network inference, audio processing, and sensor data fusion can tolerate small deviations from the mathematically exact result without any perceptible loss in quality.

This creates a clear opportunity: by deliberately introducing controlled inaccuracies into the multiplication, we can significantly reduce the amount of internal switching activity — and therefore the dynamic power consumption — without breaking the application. This concept is called **approximate computing**.

The challenge, however, is doing this in a hardware-safe way. Naively disabling logic rows can cause floating nodes, glitching, or unpredictable timing violations — all of which can corrupt the circuit's behavior. This project addresses that challenge by combining partial-product gating with operand isolation and a clean pipeline structure, validated all the way through post-layout parasitic extraction.

The specific design goals were:

- **Runtime reconfigurability** — the user can switch approximation levels on the fly using the MODE word, without redesigning the hardware.
- **Glitch-free suppression** — disabled rows are safely clamped using operand isolation cells, not just masked.
- **Pipeline robustness** — clean register boundaries prevent parasitic-induced glitches from violating timing after extraction.
- **Full characterization** — timing, power, energy, and accuracy are all measured and reported exhaustively.

<br>

---

## 3. Architecture

### 3.1 Top-Level Block Diagram

```
         A[7:0]          B[7:0]         MODE[4:0]
            │               │                │
       ┌────▼────┐     ┌────▼────┐           │
       │  8_DFF  │     │  8_DFF  │     ┌─────▼─────┐
       │(Stage 1)│     │(Stage 1)│     │   Mode    │
       └────┬────┘     └────┬────┘     │  Decoder  │
            │               │          └─────┬─────┘
            └──────────┬────┘                │ PP_ENABLE[7:0]
                       │                     │
              ┌────────▼─────────────────────▼────────┐
              │   Partial Product Generator +          │
              │       Operand Isolation Block          │
              └────────────────┬──────────────────────┘
                               │  64 gated partial products
                       ┌───────▼────────┐
                       │  Wallace Tree  │
                       │  Compression   │
                       │ (FA + HA only) │
                       └───────┬────────┘
                               │  SUM[15:0] + CARRY[15:0]
                       ┌───────▼────────┐
                       │   32_DFF       │
                       │  (Stage 2)     │
                       └───────┬────────┘
                               │
                  ┌────────────▼───────────────┐
                  │  16-bit Brent-Kung Prefix   │
                  │         Adder (PPA)         │
                  └────────────┬───────────────┘
                               │
                       ┌───────▼────────┐
                       │   16_DFF       │
                       │  (Stage 3)     │
                       └───────┬────────┘
                               │
                           Y[15:0]
                        (Final Product)
```

<br>

### 3.2 Stage 1 — Input Register and Mode Decoder

The first pipeline stage registers the two 8-bit input operands `A[7:0]` and `B[7:0]` using a bank of D flip-flops. The 5-bit `MODE[4:0]` word is also captured at this stage. Registering all inputs at the very first stage isolates any external timing variations — including setup violations or slow transitions on the input bus — from affecting the internal combinational logic.

The **Mode Decoder** is a purely combinational block that converts the 5-bit MODE word into 8 independent partial-product enable signals (`PP_ENABLE[7:0]`). It is intentionally lightweight, built using only NAND, NOR, and inverter cells, so that it satisfies the strict input-capacitance constraints of the project while also contributing negligible delay to the critical path. Since its output is captured right after the Stage 1 register, the decoder itself is not on any timing-critical path.

<br>

### 3.3 Stage 2 — Partial Product Generator and Wallace Tree

The partial product generator computes up to **64 single-bit products** of the form `PP[i][j] = A[j] AND B[i]`. Each of the 8 rows of partial products corresponds to one bit of the multiplier operand B.

When a row is enabled, its 8 product bits flow normally into the Wallace tree. When a row is disabled by the MODE decoder, its operand input to the AND gates is clamped to logic zero by the operand isolation cells, so all 8 product bits of that row are forced to zero before they can reach the compressor network. This is a crucial distinction: the isolation happens at the input, not the output, ensuring that no switching activity is generated anywhere inside the disabled row.

The **Wallace tree compression** receives these gated partial products and reduces them level by level. The design uses **only Full Adders (3-to-2 compressors) and Half Adders (2-to-2 compressors)** — no complex 4-to-2 compressors or approximate adder cells. This choice was made deliberately for three reasons:

1. It keeps the logical depth uniform and predictable across every bit-column.
2. It ensures consistent parasitic loading across the entire tree, which is important for accurate post-PEX timing analysis.
3. It simplifies the layout, since compressor placement becomes highly regular bit-slice by bit-slice.

The Wallace tree reduces all partial products into two aligned 16-bit vectors — a SUM vector and a CARRY vector — which are then captured by a bank of 32 flip-flops (Stage 2 register boundary) before being forwarded to the final adder.

<br>

### 3.4 Stage 3 — Brent-Kung Prefix Adder

The final stage uses a **16-bit Brent-Kung parallel prefix adder** to combine the SUM and CARRY vectors from the Wallace tree into the final 16-bit product output.

The Brent-Kung topology was chosen specifically because:

- Its **logarithmic prefix depth** minimizes the number of gate levels between input and output.
- Its **structured generate-propagate hierarchy** keeps global interconnect lengths short, which is especially important in a post-PEX environment where long wires introduce significant RC delay.
- It maintains **balanced fan-out** across every prefix stage, preventing any single node from becoming a timing bottleneck.

This adder block dominates the final timing path of the design. Its delay, slew, and short-circuit behavior were fully evaluated using extracted RC parasitics to confirm that the clock-to-output timing meets the project's constraints under realistic capacitive loading and interconnect resistance.

The final 16-bit result is registered in Stage 3 (16 flip-flops) before being driven onto the output port `Y[15:0]`.

<br>

---

## 4. MODE Configuration and Approximation Control

The 5-bit `MODE[4:0]` word is the central control interface of this multiplier. It determines exactly which partial-product rows contribute to the final result. The mapping is shown in the table below.

| MODE (5 bits) | PP_ENABLE [7:0] | Rows Active | Rows Disabled | Approximation Level       |
|:-------------:|:---------------:|:-----------:|:-------------:|:-------------------------:|
| `00000`       | `11111111`      | 8 of 8      | 0             | Fully accurate            |
| `00001`       | `11111100`      | 6 of 8      | 2 (LSBs)      | Light approximation       |
| `00010`       | `11110000`      | 4 of 8      | 4             | Moderate approximation    |
| `00011`       | `11000000`      | 2 of 8      | 6             | Heavy approximation       |
| `00100`       | `10000000`      | 1 of 8      | 7             | Most aggressive           |

When `MODE = 00000`, all 8 partial-product rows are active and the multiplier computes the exact 16-bit unsigned product. As the MODE index increases, progressively more rows are suppressed, starting from the least-significant rows. Suppressing lower-weight rows initially causes only small numerical errors, because those rows contribute smaller binary weights to the final result. As higher-weight rows are eventually suppressed (MODE 3 and MODE 4), the numerical error grows significantly — but so does the energy saving.

This design allows a system controller to dynamically select the right operating point based on the current workload. A neural network inference engine, for example, could run in MODE 0 for the first layer (where accuracy matters most) and switch to MODE 3 or MODE 4 for intermediate layers that are naturally more tolerant of small errors.

<br>

---

## 5. Operand Isolation and Glitch Prevention

A naive implementation of partial-product gating would simply AND the partial-product bits with the enable signal at the output of the AND gates. This would produce the correct logical result, but it would not prevent internal switching activity from occurring *inside* the disabled row.

When a partial-product row is "disabled" without operand isolation, the AND gates in that row still see toggling inputs from the operand registers. As these inputs switch, the AND gate outputs glitch briefly before being masked. These glitches can propagate into the first level of the Wallace tree compressors, where they cause unnecessary dynamic switching — consuming energy without contributing to the correct result.

This design solves the problem using **operand isolation cells**, which clamp the B-operand input to logic zero *before* it reaches the AND gates. When `PP_ENABLE[i] = 0`, the corresponding isolated B bit (`B_E[i]`) is held at zero regardless of what `B[i]` does. The AND gate therefore sees a stable zero on one input at all times, producing a stable zero output with no switching activity whatsoever.

This approach also eliminates **floating internal nodes** — a critical concern in parasitic extraction, where high-impedance nodes can be inadvertently driven by coupled capacitors from neighboring wires, causing incorrect transient logic levels.

The combined effect of operand isolation and Wallace-tree suppression is that the energy savings from each disabled row are fully realized, without any leakage from residual glitching at the compressor inputs.

<br>

---

## 6. Verification Methodology

### 6.1 Transistor-Level Verification

The fully accurate mode (`MODE = 00000`) was verified exhaustively at the transistor level inside Cadence Virtuoso. All **65,536 unique input combinations** (256 × 256) were applied to the transistor-level netlist, and each output was checked against the expected exact product. This confirmed zero errors in the accurate mode and validated that the Wallace tree, prefix adder, and pipeline registers all function correctly at the transistor level.

Performing this exhaustive sweep across all five approximation modes at the transistor level would require over 327,680 full transient simulations — computationally infeasible within the project's time constraints. For the approximate modes, a hybrid approach was used, as described below.

<br>

### 6.2 RTL Simulation and VCD Analysis

The complete multiplier was re-implemented as a behavioral RTL model in Verilog, faithfully mirroring the partial-product gating logic and pipeline structure of the transistor-level design. This RTL model was simulated using **Icarus Verilog (iverilog)** and the design was also synthesized to a gate-level netlist using **Yosys** for structural validation.

A dedicated testbench was written to sweep all 65,536 input combinations for each of the 5 MODE configurations, for a total of **327,680 test cases**. The output activity from each simulation was captured in **Value Change Dump (VCD)** format.

These VCD files were then post-processed using Python scripts that computed the following accuracy metrics for each MODE:

- **MED (Mean Error Distance):** Average absolute difference between the approximate and exact outputs across all input pairs.
- **NMED (Normalized MED):** MED normalized by the maximum possible output value (2^16 − 1).
- **WCE (Worst-Case Error):** Maximum absolute error observed across all 65,536 input pairs.
- **ER (Error Rate):** Fraction of input pairs that produce any non-zero error, expressed as a percentage.

The switching activity captured in the VCD files was also analyzed to count the total number of signal toggles per MODE, providing a direct correlation between approximation level and internal dynamic activity.

<br>

---

## 7. Timing Characterization

Timing was characterized at each pipeline stage boundary using a methodology consistent with the DVLSI course project specifications. An output load of **2 fF** with a minimum-sized buffer was used, and input capacitance compliance was verified against a reference inverter.

**Setup time** was extracted by progressively advancing input transitions toward the active clock edge until functional corruption was first observed.

**Hold time** was determined by delaying input transitions until a hold violation occurred.

**Clock-to-output (Tpcq) propagation delay** was measured as the interval between the rising clock edge and the first stable settling of the 16-bit output vector at Stage 3.

All timing parameters were measured both on the schematic netlist (Pre-PEX) and on the extracted parasitic netlist (Post-PEX). The difference between these two measurements reflects the real impact of interconnect resistance and capacitance introduced by the Wallace tree column routing and the Brent-Kung prefix-adder wiring.

| Metric                           | Pre-PEX          | Post-PEX         |
|:---------------------------------|:----------------:|:----------------:|
| Max Clock Frequency (Typical)    | 833.33 MHz       | 476 MHz          |
| Max Clock Frequency (Fast)       | 1.25 GHz         | 833.33 MHz       |
| Max Clock Frequency (Slow)       | 294.11 MHz       | 222.22 MHz       |
| Pipeline Latency                 | 3 cycles (4.8 ns)| 3 cycles (7.5 ns)|
| Propagation Delay Tpcq           | 367.83 ps        | 412.00 ps        |
| Contamination Delay Tccq         | 95.60 ps         | 153.14 ps        |

The clock-to-Q delay increases by only about **44 ps** (roughly 12%) from pre-PEX to post-PEX, confirming that the design is well-conditioned for parasitic loading. The Brent-Kung adder's balanced prefix structure is the primary reason for this robustness — no single long wire dominates the delay.

<br>

---

## 8. Power and Energy Analysis

Power and energy measurements were performed on the transistor-level netlists in Cadence Virtuoso, both before and after parasitic extraction (post-PEX). Because the multiplier is three-stage pipelined, a valid output only appears after the pipeline has been fully loaded — requiring 3 clock cycles to fill. All measurements were therefore taken over a **single-operation integration window** that begins after the pipeline is filled.

| Window Parameter  | Pre-PEX    | Post-PEX   |
|:------------------|:----------:|:----------:|
| Pipeline fill time (t₀) | 3.6 ns | 6.3 ns |
| Integration period (T)  | 1.2 ns | 2.1 ns |

For each MODE, average dynamic power was computed by integrating the instantaneous supply current `I_DD(t)` over the window `[t₀, t₀ + T]` and multiplying by `V_DD`. Energy per operation was then obtained as `E = P × T`.

| MODE    | Pre-PEX P (µW) | Pre-PEX E (fJ) | Post-PEX P (µW) | Post-PEX E (fJ) |
|:-------:|:--------------:|:--------------:|:---------------:|:---------------:|
| `00000` | 602.3          | 722.76         | 730.31          | 1533.65         |
| `00001` | 340.63         | 408.75         | 495.89          | 1041.37         |
| `00010` | 307.39         | 368.87         | 405.67          | 851.92          |
| `00011` | 211.58         | 253.90         | 307.55          | 645.86          |
| `00100` | 193.21         | 231.86         | 287.36          | 640.24          |

The most aggressive approximation mode (MODE 4) achieves approximately **3.1× energy reduction** compared to the fully accurate mode, in the post-PEX measurement. The steepest energy drop occurs between MODE 0 and MODE 1, which is consistent with the fact that suppressing the first two partial-product rows eliminates a large proportion of first-level compressor switching — the most power-intensive region of the Wallace tree.

The post-PEX values are uniformly higher than pre-PEX due to additional capacitive loading from extracted interconnects, but the relative trend across MODEs is identical in both cases, confirming that the approximation mechanism works consistently regardless of parasitic conditions.

<br>

---

## 9. Accuracy and Error Metrics

Accuracy analysis was performed using the complete RTL-driven VCD dataset generated by the Python testbench. The metrics below were computed across all 65,536 input combinations for each MODE.

### Error Metric Definitions

**Mean Error Distance (MED)**

$$
\text{MED} = \frac{1}{N} \sum_{i=1}^{N} |Y_i - \hat{Y}_i|
$$

**Normalized Mean Error Distance (NMED)**

$$
\text{NMED} = \frac{\text{MED}}{2^{16} - 1}
$$

**Worst-Case Error (WCE)**

$$
\text{WCE} = \max_{1 \le i \le N} |Y_i - \hat{Y}_i|
$$

**Error Rate (ER)**

$$
\text{ER} = \frac{\#\{Y_i \ne \hat{Y}_i\}}{N} \times 100\%
$$

Where `Y_i` is the exact output, `Ŷ_i` is the approximate output, and `N = 65,536`.

### Results Table

| MODE    | MED   | NMED  | ER        | Notes                                      |
|:-------:|:-----:|:-----:|:---------:|:------------------------------------------:|
| `00000` | 0     | 0     | 0%        | Fully accurate — zero errors               |
| `00001` | 1500  | 0.023 | ~73%      | 2 LSB rows disabled                        |
| `00010` | 3000  | 0.041 | ~87%      | 4 rows disabled                            |
| `00011` | 5200  | 0.082 | ~92%      | 6 rows disabled                            |
| `00100` | 9000  | 0.135 | ~92%      | Only 1 row active — most aggressive        |

### Key Observations

**Error Rate behavior:** The error rate jumps sharply from 0% to approximately 73% as soon as the first partial-product row is disabled (MODE 1). This is expected — even a single suppressed row introduces a non-zero error for nearly every input pair, because almost all operand combinations produce at least one non-zero contribution from that row.

**MED growth:** The mean error distance grows monotonically as the MODE increases. This reflects the increasing cumulative magnitude of the missing weighted partial products.

**WCE behavior:** The worst-case error exhibits a non-linear pattern. It rises sharply from MODE 0 to MODE 2, then shows a slight plateau or reduction at higher modes. This happens because certain high-MODE configurations produce asymmetric elimination patterns where some missing partial-product combinations cancel out across symmetric operand pairs, slightly reducing the maximum observed error.

**NMED interpretation:** The NMED of 0.135 at MODE 4 means the average error is about 13.5% of the full output range. For error-tolerant workloads like low-resolution image filtering or intermediate neural network layers, this level of inaccuracy is often acceptable, particularly given the 3.1× energy benefit.

<br>

---

## 10. Energy-Delay Product (EDP)

The Energy-Delay Product (EDP) is a figure of merit that captures both timing performance and energy efficiency simultaneously. It is computed as:

$$
\text{EDP} = E \, [\text{pJ}] \times T_{pcq} \, [\text{ps}]
$$

Since the Brent-Kung adder maintains stable timing behavior across all MODE configurations (the propagation delay `Tpcq` is essentially constant at 367.83 ps pre-PEX and 412.00 ps post-PEX), the variation in EDP across MODEs is driven almost entirely by energy differences.

| MODE    | Pre-PEX Tpcq (ps) | Pre-PEX EDP (pJ·ps) | Post-PEX Tpcq (ps) | Post-PEX EDP (pJ·ps) |
|:-------:|:-----------------:|:-------------------:|:------------------:|:--------------------:|
| `00000` | 367.83            | 265.85              | 412.00             | 631.85               |
| `00001` | 367.83            | 150.21              | 412.00             | 428.99               |
| `00010` | 367.83            | 135.83              | 412.00             | 351.19               |
| `00011` | 367.83            | 93.40               | 412.00             | 266.11               |
| `00100` | 367.83            | 85.16               | 412.00             | 263.55               |

The EDP decreases monotonically from MODE 0 to MODE 4 in both pre-PEX and post-PEX measurements. The sharpest improvement occurs between MODE 0 and MODE 1, where the EDP drops by approximately 43% (pre-PEX) with only a modest increase in error (MED = 1500). The diminishing returns at higher modes — where MODE 3 and MODE 4 have very similar EDP values — reflect the plateauing of energy savings once only a few rows remain active.

<br>

---

## 11. Pareto Frontier Analysis

The Pareto frontier plots EDP against energy for each MODE configuration, identifying which operating points cannot be improved on one axis without sacrificing the other. In this design, **MODE 3 (`00011`) and MODE 4 (`00100`)** consistently form the Pareto-optimal region — they deliver the lowest EDP values while also having the lowest energy consumption.

These two modes represent the **optimal operating points** for error-tolerant applications. They deliver approximately **3.1× energy savings** and roughly **3.1× EDP improvement** compared to the fully accurate mode, at the cost of a mean error distance of around 5,200–9,000 counts and a normalized error of 8.2–13.5%.

For practical deployment, the choice between MODE 3 and MODE 4 depends on the target application's tolerance for arithmetic error. MODE 3 offers a somewhat better accuracy (MED = 5,200) for a marginally higher energy cost, while MODE 4 provides the maximum energy saving with the largest error (MED = 9,000).

<br>

---

## 12. Repository Structure

```
approximate-multiplier-8x8/
│
├── README.md                        ← This file
├── LICENSE                          ← MIT License
│
├── rtl/
│   ├── approx_mult_8x8.v            ← Top-level approximate multiplier (RTL)
│   ├── mode_decoder.v               ← 5-bit to 8-bit PP enable decoder
│   ├── pp_generator_isolation.v     ← Partial product generator with operand isolation
│   ├── wallace_tree.v               ← Wallace tree using FA and HA only
│   └── brent_kung_adder_16bit.v     ← 16-bit Brent-Kung parallel prefix adder
│
├── testbench/
│   ├── tb_approx_mult.v             ← Main Verilog testbench (all 65536 × 5 MODEs)
│   └── tb_brent_kung.v              ← Standalone testbench for the prefix adder
│
├── simulation/
│   ├── approx_mult_mode0.vcd        ← VCD output for MODE 00000
│   ├── approx_mult_mode1.vcd        ← VCD output for MODE 00001
│   ├── approx_mult_mode2.vcd        ← VCD output for MODE 00010
│   ├── approx_mult_mode3.vcd        ← VCD output for MODE 00011
│   ├── approx_mult_mode4.vcd        ← VCD output for MODE 00100
│   └── switching_activity.png       ← Total toggle count per MODE (bar chart)
│
├── analysis/
│   ├── error_analysis.py            ← Computes MED, NMED, WCE, ER from VCD files
│   ├── vcd_parser.py                ← Utility to parse VCD output files
│   ├── toggle_counter.py            ← Counts switching activity per signal per MODE
│   └── plot_results.py              ← Generates all result plots
│
├── results/
│   ├── mode_vs_med.png              ← MED vs MODE plot
│   ├── mode_vs_nmed.png             ← NMED vs MODE plot
│   ├── mode_vs_wce.png              ← WCE vs MODE plot
│   ├── mode_vs_er.png               ← Error rate vs MODE plot
│   ├── power_vs_mode.png            ← Pre/Post PEX power vs MODE
│   ├── energy_vs_mode.png           ← Pre/Post PEX energy vs MODE
│   ├── edp_vs_mode.png              ← Pre/Post PEX EDP vs MODE
│   ├── pareto_frontier.png          ← Pareto frontier (EDP vs Energy)
│   └── accuracy_normalized.png      ← Normalized MED, NMED, ER, WCE on one plot
│
├── docs/
│   ├── DVLSI_COURSE_PROJECT_IISc.pdf   ← Full project report
│   └── slides_presentation.pdf         ← Course presentation slides
│
└── cadence/
    └── README_cadence.md            ← Notes on Cadence Virtuoso schematic and PEX setup
```

<br>

---

## 13. Tools Used

| Tool                  | Version / Notes                              | Purpose                                        |
|:----------------------|:--------------------------------------------:|:----------------------------------------------:|
| **Cadence Virtuoso**  | Industry-standard EDA                        | Schematic entry, transistor-level simulation, post-PEX characterization |
| **Icarus Verilog**    | `iverilog`                                   | RTL simulation for all approximate modes       |
| **Yosys**             | Open-source synthesis                        | RTL synthesis and gate-level netlist generation |
| **Python 3**          | With `numpy`, `matplotlib`, `vcdvcd`         | VCD parsing, error metric computation, plotting |
| **GTKWave**           | Waveform viewer                              | Visual inspection of VCD simulation output     |

<br>

---

## 14. How to Simulate (RTL)

Follow these steps to run the RTL simulation and reproduce the accuracy metrics on your own machine.

**Step 1 — Clone the repository**

```bash
git clone https://github.com/YOUR_USERNAME/approximate-multiplier-8x8.git
cd approximate-multiplier-8x8
```

**Step 2 — Install Icarus Verilog** (if not already installed)

```bash
# On Ubuntu / Debian
sudo apt install iverilog

# On macOS (using Homebrew)
brew install icarus-verilog
```

**Step 3 — Compile and run the simulation**

```bash
cd testbench
iverilog -o approx_sim ../rtl/approx_mult_8x8.v tb_approx_mult.v
vvp approx_sim
```

This will run all 327,680 test cases (65,536 inputs × 5 MODEs) and dump the VCD file.

**Step 4 — Analyze results with Python**

```bash
cd ../analysis
pip install numpy matplotlib vcdvcd
python error_analysis.py
python plot_results.py
```

The error metrics (MED, NMED, WCE, ER) will be printed to the terminal and all result plots will be saved to the `results/` folder.

**Step 5 — View waveforms (optional)**

```bash
gtkwave ../simulation/approx_mult_mode0.vcd
```

<br>

---

## 15. Key Takeaways and Learning Outcomes

This project provided several concrete insights into how approximation techniques interact with real circuit behavior under parasitic conditions.

**Energy is dominated by first-level switching, not cell count.** The most significant energy savings occur at the earliest compression levels inside the Wallace tree, where each partial-product row removal eliminates eight AND operations and an entire compressor column. Removing cells deeper in the tree — where signal activity is already lower due to carry compression — contributes far less to energy savings. This confirms that targeting the input stage is the right design strategy for low-power multipliers.

**Operand isolation is non-negotiable for correct glitch-free approximation.** Simply gating the output of AND gates is insufficient. Without clamping the operand input before the AND gate, switching activity still occurs inside disabled rows and propagates into the first compressor level. Operand isolation cells are a small overhead with a large payoff.

**Pipeline stage boundaries are critical under parasitic conditions.** Without clean register boundaries separating the three stages, parasitic-induced glitches from the Wallace tree could violate the timing constraints of the Brent-Kung adder. The pipeline partitioning in this design ensures that each combinational block is self-contained and can be characterized and validated independently.

**RTL-based exhaustive VCD analysis is the only practical way to characterize approximate circuits.** Exhaustive transistor-level simulation across all modes and all 65,536 input combinations is computationally infeasible at the SPICE level. The hybrid approach — transistor-level for the accurate mode, RTL for the approximate modes — combines precision with scalability and produces reliable accuracy metrics across the entire input domain.

**Post-PEX validation is essential for realistic performance estimation.** The pre-PEX timing and energy numbers are optimistic. The post-PEX results reflect a 12% increase in propagation delay and a ~2× increase in energy due to extracted interconnect parasitics. Without post-PEX analysis, the reported performance envelope would be misleadingly optimistic.

<br>

---

## 16. Future Work

Several architectural and layout-level improvements could further extend the capability of this design.

**Booth Encoding.** Adopting radix-4 modified Booth encoding would halve the number of partial-product rows from 8 to 4 (or 5 with a correction term). This reduces inherent switching even in the fully accurate mode and makes each approximation step more coarse-grained, which may be desirable in some applications.

**Hybrid Compressor Networks.** Introducing optimized 4-to-2 compressors alongside the existing FA/HA structure could reduce the number of Wallace tree levels, shorten the critical path, and reduce delay variability under parasitic loading — at the cost of a slightly less uniform layout.

**Dynamic Voltage and Frequency Scaling (DVFS).** Coupling the MODE control word with DVFS logic would allow the system to simultaneously lower the supply voltage and clock frequency when switching to an aggressive approximation mode, multiplying the energy savings beyond what partial-product suppression alone can achieve.

**Runtime Workload-Driven Adaptation.** A lightweight monitor circuit could automatically select the MODE based on the nature of the incoming data — for example, switching to a more accurate mode when the input values are large (where low-weight row suppression introduces proportionally larger absolute errors) and relaxing to an approximate mode for smaller inputs.

**Layout Optimization.** Targeting wirelength minimization, improved signal shielding for long prefix-adder interconnects, and reduced routing congestion in the Wallace tree bit-slices would lower coupling capacitances and further reduce post-PEX energy and delay.

<br>

---

## 17. References

1. M. Ahmadinejad and M. H. Moaiyeri, "Energy- and quality-efficient approximate multipliers for neural network and image processing applications," *IEEE Transactions on Emerging Topics in Computing*, vol. 10, no. 2, pp. 1105–1116, 2022.

2. M. Zhang, S. Nishizawa, and S. Kimura, "Area-efficient approximate 4–2 compressor and probability-based error adjustment for approximate multiplier," *IEEE Transactions on Circuits and Systems II: Express Briefs*, vol. 70, no. 5, pp. 1714–1718, May 2023.

3. F. Sabetzadeh, M. H. Moaiyeri, and M. A. Ahmadinejad, "Majority-based imprecise multiplier designs for ultra-efficient approximate image multiplication," *IEEE Transactions on Circuits and Systems I: Regular Papers*, 2022/2023.

4. S. Mondal, "Approximate 8-bit multipliers and their physical design," *Microelectronics Journal / ScienceDirect*, 2023.

5. S. Guturu, "Design methodology for highly accurate approximate compressor networks," *Journal / Elsevier*, 2023.

6. E. Esmaeili, "An efficient approximate multiplier with encoded partial products," *IET Circuits, Devices & Systems*, 2024.

7. A. Sadeghi, R. Rasheedi, I. Partin-Vaisband, and D. Pal, "Energy-efficient compact approximate multiplier for error-resilient applications," *IEEE Transactions on Circuits and Systems II: Express Briefs*, vol. 71, no. 12, Dec. 2024.

<br>

---

## 18. License

This project is released under the **MIT License**.

```
MIT License

Copyright (c) 2025 Karney Jayanath, Shreevathsa K S
Indian Institute of Science (IISc), Bangalore

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

<br>

---

*Department of Electronic Systems Engineering · Indian Institute of Science (IISc) · Bangalore, India*
*DVLSI Course Project · 2024–2025*
