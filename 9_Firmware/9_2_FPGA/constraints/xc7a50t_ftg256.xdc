# ============================================================================
# RADAR SYSTEM FPGA CONSTRAINTS
# ============================================================================
# Device: XC7A50T-2FTG256I (FTG256 package)
# Board:  AERIS-10 Phased Array Radar — Main Board
# Source: Pin assignments extracted from Eagle schematic (RADAR_Main_Board.sch)
#         FPGA = U42
#
# NOTE: The README and prior version of this file incorrectly referenced
#       XC7A100TCSG324-1. The physical board uses XC7A50T in a 256-ball BGA
#       (FTG256). All PACKAGE_PIN values below are FTG256 ball locations.
#
# I/O Bank Voltage Summary:
#   Bank 0:  VCCO = 3.3V (JTAG, flash CS)
#   Bank 14: VCCO = 2.5V (ADC LVDS_25 data — placer-enforced; adc_pwdn as LVCMOS25)
#   Bank 15: VCCO = 3.3V (DAC, clocks, STM32 SPI 3.3V side, DIG bus, mixer)
#   Bank 34: VCCO = 1.8V (ADAR1000 beamformer control, SPI 1.8V side)
#   Bank 35: VCCO = 3.3V (FT2232H USB 2.0 FIFO — 15 signals)
#
# DRC Fix History:
#   - PLIO-9 (REVERTED): Previously moved clk_120m_dac from C13 (N-type) to
#     D13 (P-type MRCC) to satisfy the MRCC preference. However, a schematic
#     audit (KiCad netlist export from the Eagle schematic, U42 pad->net map)
#     revealed that D13 is UNCONNECTED on the physical PCB. The real
#     /FPGA_DAC_CLOCK net from AD9523 OUT11 lands on C13 (IO_L11N_T1_SRCC_15,
#     N-type). Moved back to C13 and added CLOCK_DEDICATED_ROUTE FALSE,
#     matching the ft_clkout treatment on C4 (N-type MRCC).
#   - Schematic audit added pin constraints for previously-unconstrained
#     signals connected to the FPGA in hardware: ADC_OR_P/N (M6/N6, AD9484
#     overflow flag), /FPGA_ADC_CLOCK_P/N (N11/N12, 400 MHz observation tap
#     of the AD9523->AD9484 sample clock). Added to 50T wrapper as
#     anchored-but-unused inputs to secure pin assignment and prevent
#     accidental future contention; full RTL consumers are a follow-up.
#   - PLIO-9 (original, historical): FT2232H CLKOUT routed to C4
#     (IO_L12N_T1_MRCC_35, N-type). Clock inputs normally use P-type MRCC
#     pins, but IBUFG works correctly on N-type. Demote PLIO-9 to warning
#     in build script.
#   - BIVC-1 / Place 30-372: Bank 14 must have a single VCCO. LVDS_25 forces
#     VCCO=2.5V, so adc_pwdn was changed from LVCMOS33 to LVCMOS25 to match.
#     IBUFDS input buffers are VCCO-independent. BIVC-1 also waived via
#     set_property SEVERITY in the build script as an additional safety net.
#     in the build script. adc_pwdn (LVCMOS25) coexists in the same bank.
#   - UCIO/NSTD: Unconstrained ports (FT601 ports inactive with USB_MODE=1,
#     status/debug outputs have no physical pins). Handled with SEVERITY
#     demotion + default IOSTANDARD.
# ============================================================================

# ============================================================================
# CONFIGURATION
# ============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# ============================================================================
# DRC WAIVERS — Hardware-Level Known Issues (applied in build script)
# ============================================================================
# BIVC-1: Bank 14 VCCO=3.3V with LVDS_25 inputs + LVCMOS33 adc_pwdn.
# IBUFDS input buffers are VCCO-independent on 7-series — they use an
# internal differential amplifier that works correctly at any VCCO.
# The BIVC-1 DRC check is intended for OBUFDS *outputs* where VCCO
# directly affects the output swing. Since Bank 14 has only LVDS inputs
# and one LVCMOS33 output, this is safe to demote to a warning.
# → Applied in build_50t_test.tcl: set_property SEVERITY {Warning} [get_drc_checks BIVC-1]
#
# NSTD-1 / UCIO-1: Unconstrained ports — FT601 USB ports (inactive with
# USB_MODE=1 generate block), dac_clk (DAC clock comes from AD9523, not FPGA),
# and all status/debug outputs (no physical pins available). These ports are
# present in the shared RTL but have no connections on the 50T board.
# → Applied in build_50t_test.tcl: set_property SEVERITY {Warning} [get_drc_checks {NSTD-1 UCIO-1}]

# ============================================================================
# CLOCK CONSTRAINTS
# ============================================================================

# 100MHz System Clock (AD9523 OUT6 → FPGA_SYS_CLOCK → Bank 15 MRCC pin E12)
set_property PACKAGE_PIN E12 [get_ports {clk_100m}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk_100m}]
create_clock -name clk_100m -period 10.0 [get_ports {clk_100m}]
set_input_jitter [get_clocks clk_100m] 0.1

# 120MHz DAC Clock (AD9523 OUT11 → /FPGA_DAC_CLOCK → Bank 15 pin C13)
# NOTE: The physical DAC (U3, AD9708) receives its clock directly from the
#       AD9523 via a separate net (DAC_CLOCK), NOT from the FPGA. The FPGA
#       uses this clock input for internal DAC data timing only. The RTL port
#       `dac_clk` is an RTL output that assigns clk_120m directly. It has no
#       physical pin on the 50T board and is left unconnected here. The port
#       CANNOT be removed from the RTL because the 200T board uses it with
#       ODDR clock forwarding (pin H17, see xc7a200t_fbg484.xdc).
#
# PIN: C13 is IO_L11N_T1_SRCC_15 (N-type SRCC). A prior commit attempted to
# move this to D13 (MRCC P-type) to satisfy PLIO-9, but the schematic audit
# showed D13 is UNCONNECTED on the PCB — the /FPGA_DAC_CLOCK net physically
# lands on C13. Moving to D13 made the DAC clock input float. Restored to
# C13 and forced CLOCK_DEDICATED_ROUTE FALSE (same mechanism as ft_clkout on
# C4), which routes the IBUFG output through general fabric to a BUFG.
set_property PACKAGE_PIN C13 [get_ports {clk_120m_dac}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk_120m_dac}]
create_clock -name clk_120m_dac -period 8.333 [get_ports {clk_120m_dac}]
set_input_jitter [get_clocks clk_120m_dac] 0.1
# C13 is N-type SRCC (not dedicated-clock-capable); override the DRC check.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {clk_120m_dac_IBUF}]

# ADC DCO Clock (400MHz LVDS — AD9523 OUT5 → AD9484 → FPGA, Bank 14 MRCC)
# NOTE: LVDS_25 is the only valid differential input standard on 7-series HR
# banks. IBUFDS input buffers are VCCO-independent — they work correctly even
# with VCCO=3.3V. The BIVC-1 DRC (voltage conflict with LVCMOS33 adc_pwdn)
# is waived in the build script since this bank has only LVDS *inputs*.
set_property PACKAGE_PIN N14 [get_ports {adc_dco_p}]
set_property PACKAGE_PIN P14 [get_ports {adc_dco_n}]
set_property IOSTANDARD LVDS_25 [get_ports {adc_dco_p}]
set_property IOSTANDARD LVDS_25 [get_ports {adc_dco_n}]
set_property DIFF_TERM TRUE [get_ports {adc_dco_p}]
create_clock -name adc_dco_p -period 2.5 [get_ports {adc_dco_p}]
set_input_jitter [get_clocks adc_dco_p] 0.05

# --------------------------------------------------------------------------
# FT2232H 60 MHz CLKOUT (Bank 35, MRCC pin C4)
# --------------------------------------------------------------------------
# The FT2232H provides a 60 MHz clock in 245 Synchronous FIFO mode.
# Pin C4 is IO_L12N_T1_MRCC_35 (N-type of MRCC pair). Vivado requires
# CLOCK_DEDICATED_ROUTE FALSE for clock inputs on N-type MRCC pins
# (Place 30-876). The schematic routes CLKOUT to C4; this cannot be
# changed without a board respin. The clock still uses an IBUFG and
# reaches the clock network — the constraint only disables the DRC check.
set_property PACKAGE_PIN C4 [get_ports {ft_clkout}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_clkout}]
create_clock -name ft_clkout -period 16.667 [get_ports {ft_clkout}]
set_input_jitter [get_clocks ft_clkout] 0.2
# N-type MRCC pin requires dedicated route override (Place 30-876)
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {ft_clkout_IBUF}]

# ============================================================================
# RESET (Active-Low)
# ============================================================================
# DIG_4 (STM32 PD12 → FPGA Bank 15 pin E15)
# STM32 firmware uses HAL_GPIO_WritePin to assert/deassert FPGA reset.

set_property PACKAGE_PIN E15 [get_ports {reset_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {reset_n}]
set_property PULLUP true [get_ports {reset_n}]

# ============================================================================
# TRANSMITTER INTERFACE (DAC — Bank 15, VCCO=3.3V)
# ============================================================================

# DAC Data Bus (8-bit) — AD9708 data inputs via schematic nets DAC_0..DAC_7
set_property PACKAGE_PIN A14 [get_ports {dac_data[0]}]
set_property PACKAGE_PIN A13 [get_ports {dac_data[1]}]
set_property PACKAGE_PIN A12 [get_ports {dac_data[2]}]
set_property PACKAGE_PIN B11 [get_ports {dac_data[3]}]
set_property PACKAGE_PIN B10 [get_ports {dac_data[4]}]
set_property PACKAGE_PIN A10 [get_ports {dac_data[5]}]
set_property PACKAGE_PIN A9  [get_ports {dac_data[6]}]
set_property PACKAGE_PIN A8  [get_ports {dac_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[*]}]
set_property SLEW FAST [get_ports {dac_data[*]}]
set_property DRIVE 8 [get_ports {dac_data[*]}]

# DAC Clock Output — NOT DIRECTLY WIRED TO DAC IN SCHEMATIC
# The DAC chip (U3) receives its clock from AD9523 via a separate net
# (DAC_CLOCK), not from the FPGA. The RTL `dac_clk` output has no
# physical pin. Comment out or remove from RTL.
# set_property PACKAGE_PIN ??? [get_ports {dac_clk}]
# set_property IOSTANDARD LVCMOS33 [get_ports {dac_clk}]
# set_property SLEW FAST [get_ports {dac_clk}]

# DAC Sleep Control — DAC_SLEEP net
set_property PACKAGE_PIN A15 [get_ports {dac_sleep}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_sleep}]

# RF Switch Control — M3S_VCTRL net
set_property PACKAGE_PIN G15 [get_ports {fpga_rf_switch}]
set_property IOSTANDARD LVCMOS33 [get_ports {fpga_rf_switch}]

# Mixer Enables — MIX_RX_EN, MIX_TX_EN nets
set_property PACKAGE_PIN D11 [get_ports {rx_mixer_en}]
set_property PACKAGE_PIN C11 [get_ports {tx_mixer_en}]
set_property IOSTANDARD LVCMOS33 [get_ports {rx_mixer_en}]
set_property IOSTANDARD LVCMOS33 [get_ports {tx_mixer_en}]

# ============================================================================
# ADAR1000 BEAMFORMER CONTROL (Bank 34, VCCO=1.8V)
# ============================================================================

# ADAR1000 TX Load Pins (via level shifters, active-high pulse)
set_property PACKAGE_PIN P3 [get_ports {adar_tx_load_1}]
set_property PACKAGE_PIN T4 [get_ports {adar_tx_load_2}]
set_property PACKAGE_PIN R3 [get_ports {adar_tx_load_3}]
set_property PACKAGE_PIN R2 [get_ports {adar_tx_load_4}]

# ADAR1000 RX Load Pins
set_property PACKAGE_PIN M5 [get_ports {adar_rx_load_1}]
set_property PACKAGE_PIN T2 [get_ports {adar_rx_load_2}]
set_property PACKAGE_PIN R1 [get_ports {adar_rx_load_3}]
set_property PACKAGE_PIN N4 [get_ports {adar_rx_load_4}]

# Bank 34 VCCO = 1.8V → must use LVCMOS18 (not LVCMOS33)
set_property IOSTANDARD LVCMOS18 [get_ports {adar_*_load_*}]

# ADAR1000 TR (Transmit/Receive) Pins
set_property PACKAGE_PIN N2 [get_ports {adar_tr_1}]
set_property PACKAGE_PIN N1 [get_ports {adar_tr_2}]
set_property PACKAGE_PIN P1 [get_ports {adar_tr_3}]
set_property PACKAGE_PIN P4 [get_ports {adar_tr_4}]
set_property IOSTANDARD LVCMOS18 [get_ports {adar_tr_*}]

# ============================================================================
# LEVEL SHIFTER SPI INTERFACE (STM32 ↔ ADAR1000)
# ============================================================================

# 3.3V Side (from STM32, Bank 15, VCCO=3.3V)
set_property PACKAGE_PIN J16 [get_ports {stm32_sclk_3v3}]
set_property PACKAGE_PIN H13 [get_ports {stm32_mosi_3v3}]
set_property PACKAGE_PIN G14 [get_ports {stm32_miso_3v3}]
set_property PACKAGE_PIN F14 [get_ports {stm32_cs_adar1_3v3}]
set_property PACKAGE_PIN H16 [get_ports {stm32_cs_adar2_3v3}]
set_property PACKAGE_PIN G16 [get_ports {stm32_cs_adar3_3v3}]
set_property PACKAGE_PIN J15 [get_ports {stm32_cs_adar4_3v3}]
set_property IOSTANDARD LVCMOS33 [get_ports {stm32_*_3v3}]

# 1.8V Side (to ADAR1000, Bank 34, VCCO=1.8V)
set_property PACKAGE_PIN P5 [get_ports {stm32_sclk_1v8}]
set_property PACKAGE_PIN M1 [get_ports {stm32_mosi_1v8}]
set_property PACKAGE_PIN N3 [get_ports {stm32_miso_1v8}]
set_property PACKAGE_PIN L5 [get_ports {stm32_cs_adar1_1v8}]
set_property PACKAGE_PIN L4 [get_ports {stm32_cs_adar2_1v8}]
set_property PACKAGE_PIN M4 [get_ports {stm32_cs_adar3_1v8}]
set_property PACKAGE_PIN M2 [get_ports {stm32_cs_adar4_1v8}]
set_property IOSTANDARD LVCMOS18 [get_ports {stm32_*_1v8}]

# ============================================================================
# STM32 CONTROL INTERFACE (DIG bus, Bank 15, VCCO=3.3V)
# ============================================================================
# DIG_0..DIG_4 are STM32 outputs (PD8-PD12) → FPGA inputs
# DIG_5..DIG_7 are STM32 inputs (PD13-PD15) ← FPGA outputs (unused in RTL)

set_property PACKAGE_PIN F13 [get_ports {stm32_new_chirp}]       ;# DIG_0 (PD8)
set_property PACKAGE_PIN E16 [get_ports {stm32_new_elevation}]   ;# DIG_1 (PD9)
set_property PACKAGE_PIN D16 [get_ports {stm32_new_azimuth}]     ;# DIG_2 (PD10)
set_property PACKAGE_PIN F15 [get_ports {stm32_mixers_enable}]   ;# DIG_3 (PD11)
set_property IOSTANDARD LVCMOS33 [get_ports {stm32_new_*}]
set_property IOSTANDARD LVCMOS33 [get_ports {stm32_mixers_enable}]
# reset_n is DIG_4 (PD12) — constrained above in the RESET section

# DIG_5 = H11, DIG_6 = G12, DIG_7 = H12 — FPGA→STM32 status outputs
# DIG_5: AGC saturation flag (PD13 on STM32)
# DIG_6: AGC enable flag (PD14) — mirrors FPGA host_agc_enable to STM32
# DIG_7: reserved (PD15)
set_property PACKAGE_PIN H11 [get_ports {gpio_dig5}]
set_property PACKAGE_PIN G12 [get_ports {gpio_dig6}]
set_property PACKAGE_PIN H12 [get_ports {gpio_dig7}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_dig*}]
set_property DRIVE 8 [get_ports {gpio_dig*}]
set_property SLEW SLOW [get_ports {gpio_dig*}]

# ============================================================================
# ADC INTERFACE (LVDS — Bank 14, VCCO=3.3V)
# ============================================================================

# ADC Data (8-bit LVDS pairs from AD9484)
set_property PACKAGE_PIN P15 [get_ports {adc_d_p[0]}]
set_property PACKAGE_PIN P16 [get_ports {adc_d_n[0]}]
set_property PACKAGE_PIN R15 [get_ports {adc_d_p[1]}]
set_property PACKAGE_PIN R16 [get_ports {adc_d_n[1]}]
set_property PACKAGE_PIN T14 [get_ports {adc_d_p[2]}]
set_property PACKAGE_PIN T15 [get_ports {adc_d_n[2]}]
set_property PACKAGE_PIN R13 [get_ports {adc_d_p[3]}]
set_property PACKAGE_PIN T13 [get_ports {adc_d_n[3]}]
set_property PACKAGE_PIN R10 [get_ports {adc_d_p[4]}]
set_property PACKAGE_PIN R11 [get_ports {adc_d_n[4]}]
set_property PACKAGE_PIN T9  [get_ports {adc_d_p[5]}]
set_property PACKAGE_PIN T10 [get_ports {adc_d_n[5]}]
set_property PACKAGE_PIN T7  [get_ports {adc_d_p[6]}]
set_property PACKAGE_PIN T8  [get_ports {adc_d_n[6]}]
set_property PACKAGE_PIN R6  [get_ports {adc_d_p[7]}]
set_property PACKAGE_PIN R7  [get_ports {adc_d_n[7]}]

# ADC DCO Clock (LVDS) — already constrained above in CLOCK section

# ADC Power Down — ADC_PWRD net (single-ended, Bank 14)
# Uses LVCMOS25 to be voltage-compatible with LVDS_25 in the same bank.
# The placer enforces a single VCCO per bank; LVDS_25 demands VCCO=2.5V.
# LVCMOS25 output drives the AD9484 PWDN pin (CMOS threshold ~0.8V) safely.
# On the physical board (VCCO=3.3V), output swings follow actual VCCO.
set_property PACKAGE_PIN T5 [get_ports {adc_pwdn}]
set_property IOSTANDARD LVCMOS25 [get_ports {adc_pwdn}]

# LVDS I/O Standard — LVDS_25 is the only valid differential input standard
# on 7-series HR banks. IBUFDS inputs work correctly regardless of VCCO.
set_property IOSTANDARD LVDS_25 [get_ports {adc_d_p[*]}]
set_property IOSTANDARD LVDS_25 [get_ports {adc_d_n[*]}]

# Differential termination — DIFF_TERM uses a ~100-ohm on-die termination
# inside the IBUFDS. This is VCCO-independent for 7-series input buffers.
# RTL IBUFDS uses DIFF_TERM("FALSE") so this XDC property takes precedence.
set_property DIFF_TERM TRUE [get_ports {adc_d_p[*]}]

# Input delay for ADC data relative to DCO (adjust based on PCB trace length)
# DDR interface: constrain both rising and falling clock edges
set_input_delay -clock [get_clocks adc_dco_p] -max 1.0 [get_ports {adc_d_p[*]}]
set_input_delay -clock [get_clocks adc_dco_p] -min 0.2 [get_ports {adc_d_p[*]}]
set_input_delay -clock [get_clocks adc_dco_p] -max 1.0 -clock_fall [get_ports {adc_d_p[*]}] -add_delay
set_input_delay -clock [get_clocks adc_dco_p] -min 0.2 -clock_fall [get_ports {adc_d_p[*]}] -add_delay

# --------------------------------------------------------------------------
# AD9484 Overflow / Out-Of-Range flag (schematic nets ADC_OR_P / ADC_OR_N)
# --------------------------------------------------------------------------
# AD9484 differential OR output on FPGA pads M6 (OR_P) / N6 (OR_N), Bank 14.
# This is the AD9484's full-scale overflow indicator, useful for AGC /
# gain-ranging feedback. The 50T RTL wrapper anchors this with an IBUFDS
# (DONT_TOUCH) so the pads cannot be accidentally driven as outputs (which
# would cause contention with the AD9484 driver). A future PR should wire
# the buffered signal into the receive-path status flags.
set_property PACKAGE_PIN M6 [get_ports {adc_or_p}]
set_property PACKAGE_PIN N6 [get_ports {adc_or_n}]
set_property IOSTANDARD LVDS_25 [get_ports {adc_or_p}]
set_property IOSTANDARD LVDS_25 [get_ports {adc_or_n}]
set_property DIFF_TERM TRUE [get_ports {adc_or_p}]

# --------------------------------------------------------------------------
# FPGA observation of AD9523->AD9484 sample clock (/FPGA_ADC_CLOCK_P/N)
# --------------------------------------------------------------------------
# AD9523 drives the AD9484 sample clock directly; the same differential
# pair is tapped to FPGA pads N11 (P) / N12 (N), Bank 14, MRCC-capable.
# This is an INPUT-ONLY tap (FPGA must never drive these pads — that would
# contend with the AD9523 driver feeding the ADC). The 50T wrapper anchors
# with IBUFDS + DONT_TOUCH so the pad assignment is preserved across all
# synthesis/optimization stages. The buffered net is unconsumed for now;
# create_clock and clock_groups are deferred until an RTL consumer exists
# (see commented template below).
set_property PACKAGE_PIN N11 [get_ports {fpga_adc_clock_p}]
set_property PACKAGE_PIN N12 [get_ports {fpga_adc_clock_n}]
set_property IOSTANDARD LVDS_25 [get_ports {fpga_adc_clock_p}]
set_property IOSTANDARD LVDS_25 [get_ports {fpga_adc_clock_n}]
set_property DIFF_TERM TRUE [get_ports {fpga_adc_clock_p}]
# No create_clock here on purpose: the IBUFDS output is unconsumed (anchored
# via DONT_TOUCH only), so declaring it as a clock would only generate
# "clock has no registered destinations" warnings. When a follow-up PR adds
# an actual consumer, add:
#     create_clock -name fpga_adc_clock -period 2.5 [get_ports {fpga_adc_clock_p}]
#     set_input_jitter [get_clocks fpga_adc_clock] 0.05
#     set_clock_groups -asynchronous -group [get_clocks fpga_adc_clock] ...

# ============================================================================
# FT2232H USB 2.0 INTERFACE (Bank 35, VCCO=3.3V)
# ============================================================================
# FT2232H (U6) Channel A in 245 Synchronous FIFO mode.
# All signals are direct connections to FPGA Bank 35 (LVCMOS33).
# Pin mapping extracted from Eagle schematic (RADAR_Main_Board.sch).
#
# The FT2232H replaces the previously-unwired FT601 on the 50T production
# board. The 200T dev board retains FT601 USB 3.0 (32-bit).
# ============================================================================

# 8-bit bidirectional data bus (ADBUS0–ADBUS7)
set_property PACKAGE_PIN K1 [get_ports {ft_data[0]}]   ;# ADBUS0 → IO_L22P_T3_35
set_property PACKAGE_PIN J3 [get_ports {ft_data[1]}]   ;# ADBUS1 → IO_L21P_T3_DQS_35
set_property PACKAGE_PIN H3 [get_ports {ft_data[2]}]   ;# ADBUS2 → IO_L21N_T3_DQS_35
set_property PACKAGE_PIN G4 [get_ports {ft_data[3]}]   ;# ADBUS3 → IO_L16N_T2_35
set_property PACKAGE_PIN F2 [get_ports {ft_data[4]}]   ;# ADBUS4 → IO_L15P_T2_DQS_35
set_property PACKAGE_PIN D1 [get_ports {ft_data[5]}]   ;# ADBUS5 → IO_L10N_T1_AD15N_35
set_property PACKAGE_PIN C3 [get_ports {ft_data[6]}]   ;# ADBUS6 → IO_L7P_T1_AD6P_35
set_property PACKAGE_PIN C1 [get_ports {ft_data[7]}]   ;# ADBUS7 → IO_L9P_T1_DQS_AD7P_35
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[*]}]

# Control signals (active low where noted)
set_property PACKAGE_PIN A2 [get_ports {ft_rxf_n}]     ;# ACBUS0 → IO_L8N_T1_AD14N_35
set_property PACKAGE_PIN B2 [get_ports {ft_txe_n}]     ;# ACBUS1 → IO_L8P_T1_AD14P_35
set_property PACKAGE_PIN A3 [get_ports {ft_rd_n}]      ;# ACBUS2 → IO_L4N_T0_35
set_property PACKAGE_PIN A4 [get_ports {ft_wr_n}]      ;# ACBUS3 → IO_L3N_T0_DQS_AD5N_35
set_property PACKAGE_PIN A5 [get_ports {ft_siwu}]      ;# ACBUS4 → IO_L3P_T0_DQS_AD5P_35
set_property PACKAGE_PIN B7 [get_ports {ft_oe_n}]      ;# ACBUS6 → IO_L1P_T0_AD4P_35
set_property IOSTANDARD LVCMOS33 [get_ports {ft_rxf_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_txe_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_rd_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_wr_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_siwu}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_oe_n}]

# Output timing: SLEW FAST + DRIVE 8 for FT2232H signals
set_property SLEW FAST [get_ports {ft_rd_n}]
set_property SLEW FAST [get_ports {ft_wr_n}]
set_property SLEW FAST [get_ports {ft_oe_n}]
set_property SLEW FAST [get_ports {ft_siwu}]
set_property SLEW FAST [get_ports {ft_data[*]}]
set_property DRIVE 8 [get_ports {ft_rd_n}]
set_property DRIVE 8 [get_ports {ft_wr_n}]
set_property DRIVE 8 [get_ports {ft_oe_n}]
set_property DRIVE 8 [get_ports {ft_siwu}]
set_property DRIVE 8 [get_ports {ft_data[*]}]

# ft_clkout constrained above in CLOCK CONSTRAINTS section (C4, 60 MHz)

# --------------------------------------------------------------------------
# FT2232H Source-Synchronous Timing Constraints
# --------------------------------------------------------------------------
# FT2232H 245 Synchronous FIFO mode timing (60 MHz, period = 16.667 ns):
#
# FPGA Read Path (FT2232H drives data, FPGA samples):
#   - Data valid before CLKOUT rising edge: t_vr(max) = 7.0 ns
#   - Data hold after CLKOUT rising edge:   t_hr(min) = 0.0 ns
#   - Input delay max = period - t_vr = 16.667 - 7.0 = 9.667 ns
#   - Input delay min = t_hr = 0.0 ns
#
# FPGA Write Path (FPGA drives data, FT2232H samples):
#   - Data setup before next CLKOUT rising: t_su = 5.0 ns
#   - Data hold after CLKOUT rising:        t_hd = 0.0 ns
#   - Board trace skew budget:               ~0.5 ns
#   - Output delay max = t_su + trace_max = 5.0 + 0.5 = 5.5 ns
#   - Output delay min = t_hd - trace_min = 0.0 - 0.0 = 0.0 ns
#
# NOTE: Historical XDC used 'period - t_su = 11.667 ns' for output_delay -max,
# which is the wrong interpretation: set_output_delay takes the external setup
# requirement (+trace), not the remaining timing budget. The old value forced
# Vivado to close a path assuming FT2232H requires 11.667 ns of setup, which
# it does not, and caused WNS=-5.350 ns failures on ft_data/ft_rd_n/ft_wr_n/
# ft_oe_n/ft_siwu paths given the 5.513 ns clock insertion delay on the
# non-dedicated C4 routing.
# --------------------------------------------------------------------------

# Input delays: FT2232H → FPGA (data bus and status signals)
#
# -min revision (Build N+1): was 0.0 ns, now 1.0 ns.
# Rationale: set_input_delay -min is the EARLIEST time data can change at the
# FPGA pin after the launch clock edge, i.e. FT2232H Tco_min + trace_min.
# Setting -min 0.0 claimed data could change simultaneously with the clock
# edge, which is pessimistically tight for hold analysis and caused a
# -0.079 ns hold violation on ft_rxf_n → FSM_sequential_wr_state in Build N
# (due to 2.895 ns clock insertion delay on non-dedicated C4 routing).
# FT2232H Sync FIFO Tco is spec'd 1–4 ns; using 1.0 ns is conservative and
# still covers worst-case silicon. Invariant preserved: hold_margin =
# Tco_min + trace_min - clk_insertion_delay - Th_fpga ≥ 0.
set_input_delay -clock [get_clocks ft_clkout] -max 9.667 [get_ports {ft_data[*]}]
set_input_delay -clock [get_clocks ft_clkout] -min 1.0   [get_ports {ft_data[*]}]
set_input_delay -clock [get_clocks ft_clkout] -max 9.667 [get_ports {ft_rxf_n}]
set_input_delay -clock [get_clocks ft_clkout] -min 1.0   [get_ports {ft_rxf_n}]
set_input_delay -clock [get_clocks ft_clkout] -max 9.667 [get_ports {ft_txe_n}]
set_input_delay -clock [get_clocks ft_clkout] -min 1.0   [get_ports {ft_txe_n}]

# Output delays: FPGA → FT2232H (control strobes and data bus when writing)
set_output_delay -clock [get_clocks ft_clkout] -max 5.5 [get_ports {ft_data[*]}]
set_output_delay -clock [get_clocks ft_clkout] -min 0.0 [get_ports {ft_data[*]}]
set_output_delay -clock [get_clocks ft_clkout] -max 5.5 [get_ports {ft_rd_n}]
set_output_delay -clock [get_clocks ft_clkout] -min 0.0 [get_ports {ft_rd_n}]
set_output_delay -clock [get_clocks ft_clkout] -max 5.5 [get_ports {ft_wr_n}]
set_output_delay -clock [get_clocks ft_clkout] -min 0.0 [get_ports {ft_wr_n}]
set_output_delay -clock [get_clocks ft_clkout] -max 5.5 [get_ports {ft_oe_n}]
set_output_delay -clock [get_clocks ft_clkout] -min 0.0 [get_ports {ft_oe_n}]
set_output_delay -clock [get_clocks ft_clkout] -max 5.5 [get_ports {ft_siwu}]
set_output_delay -clock [get_clocks ft_clkout] -min 0.0 [get_ports {ft_siwu}]

# ============================================================================
# STATUS / DEBUG OUTPUTS — NO PHYSICAL CONNECTIONS
# ============================================================================
# The following RTL output ports have no corresponding FPGA pins in the
# schematic. The only FPGA→STM32 outputs available are DIG_5 (H11),
# DIG_6 (G12), and DIG_7 (H12) — only 3 pins for potentially 60+ signals.
#
# These constraints are commented out. If status readback is needed, either:
#   (a) Multiplex selected status bits onto DIG_5/6/7, or
#   (b) Send status data over the SPI interface, or
#   (c) Route through USB once FT601 is wired.
#
# Ports affected:
#   current_elevation[5:0], current_azimuth[5:0], current_chirp[5:0],
#   new_chirp_frame, dbg_doppler_data[31:0], dbg_doppler_valid,
#   dbg_doppler_bin[4:0], dbg_range_bin[5:0], system_status[3:0]
# ============================================================================

# ============================================================================
# TIMING EXCEPTIONS
# ============================================================================

# False paths for asynchronous STM32 control signals (active-edge toggle interface)
set_false_path -from [get_ports {stm32_new_*}]
set_false_path -from [get_ports {stm32_mixers_enable}]

# --------------------------------------------------------------------------
# Async reset recovery/removal false paths
#
# The async reset (reset_n) is held asserted for multiple clock cycles during
# power-on and system reset. The recovery/removal timing checks on CLR pins
# are over-constrained for this use case:
#   - reset_sync_reg[1] fans out to 1000+ registers across the FPGA
#   - Route delay alone exceeds the clock period (18+ ns for 10ns period)
#   - Reset deassertion order is not functionally critical — all registers
#     come out of reset within a few cycles of each other
# --------------------------------------------------------------------------
set_false_path -from [get_cells reset_sync_reg[*]] -to [get_pins -filter {REF_PIN_NAME == CLR} -of_objects [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ REGISTER.*.*}]]

# --------------------------------------------------------------------------
# Clock Domain Crossing — asynchronous clock groups
#
# Rationale: prefer `set_clock_groups -asynchronous` over pairwise
# `set_false_path -from CLK -to CLK`. The latter is an STA antipattern:
# it disables *all* paths between the two domains, including the
# synchronizer paths themselves and any future inadvertent crossings,
# which can mask real CDC bugs that only show up at temperature/voltage
# corners. Clock-groups is the idiomatic way to declare domains async
# while still letting STA flag newly-introduced unrelated paths.
#
# Register-level false_paths (e.g. reset_sync_reg above) remain
# appropriate — those restrict the waiver to specific, audited endpoints.
#
# Groups declared here mirror the pairwise false_paths that existed
# previously; no new pair is declared async.
# --------------------------------------------------------------------------

# clk_100m ↔ adc_dco_p (400 MHz): DDC has internal CDC synchronizers
set_clock_groups -asynchronous \
    -group [get_clocks clk_100m] \
    -group [get_clocks adc_dco_p]

# clk_100m ↔ clk_120m_dac: CDC via synchronizers in radar_system_top
set_clock_groups -asynchronous \
    -group [get_clocks clk_100m] \
    -group [get_clocks clk_120m_dac]

# FT2232H CDC: clk_100m ↔ ft_clkout (60 MHz), toggle CDC in RTL
set_clock_groups -asynchronous \
    -group [get_clocks clk_100m] \
    -group [get_clocks ft_clkout]

# FT2232H CDC: clk_120m_dac ↔ ft_clkout (no direct crossing, but belt-and-suspenders)
set_clock_groups -asynchronous \
    -group [get_clocks clk_120m_dac] \
    -group [get_clocks ft_clkout]

# ============================================================================
# PHYSICAL CONSTRAINTS
# ============================================================================

# Pull up unused pins to prevent floating inputs
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]

# ============================================================================
# ADDITIONAL NOTES
# ============================================================================
#
# 1. ADC Sampling Clock: FPGA_ADC_CLOCK_P/N (N11/N12) is the 400 MHz LVDS
#    clock from AD9523 OUT5 that drives the AD9484. It connects to FPGA MRCC
#    pins but is not used as an FPGA clock input — the ADC returns data with
#    its own DCO (adc_dco_p/n on N14/P14).
#
# 2. Clock Test: FPGA_CLOCK_TEST (H14) is a 20 MHz LVCMOS output from the
#    FPGA, configured by AD9523 OUT7. Not currently used in RTL.
#
# 3. SPI Flash: FPGA_FLASH_CS (E8), FPGA_FLASH_CLK (J13),
#    FPGA_FLASH_D0 (J14), D1 (K15), D2 (K16), D3 (L12), unnamed (L13).
#    These are typically handled by Vivado bitstream configuration and do
#    not need explicit XDC constraints for user logic.
#
# 4. JTAG: FPGA_TCK (L7), FPGA_TDI (N7), FPGA_TDO (N8), FPGA_TMS (M7).
#    Dedicated pins — no XDC constraints needed.
#
# 5. dac_clk port: Not connected on the 50T board (DAC clocked directly from
#    AD9523). The RTL port exists for 200T board compatibility, where the FPGA
#    forwards the DAC clock via ODDR to pin H17 with generated clock and
#    timing constraints (see xc7a200t_fbg484.xdc). Do NOT remove from RTL.
#
# ============================================================================
# END OF CONSTRAINTS
# ============================================================================
