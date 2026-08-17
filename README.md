# Changing Causal Structure of the Climate System in Southeastern Türkiye

### A Transfer Entropy and Climate Network Approach

<p align="center">
  <img src="https://img.shields.io/badge/R-4.6.1-276DC3?logo=r&logoColor=white">
  <img src="https://img.shields.io/badge/Data-NASA%20POWER-orange">
  <img src="https://img.shields.io/badge/Period-1981--2025-green">
  <img src="https://img.shields.io/badge/Method-Transfer%20Entropy-purple">
  <img src="https://img.shields.io/badge/Analysis-Climate%20Network-red">
</p>

---

## Overview

Climate change is not only expressed through long-term trends in individual climate variables. It can also modify the **relationships, dependencies and information flows among climate variables**.

This project investigates whether the causal structure of the climate system in **Southeastern Türkiye** has changed during the 1981–2025 period.

Rather than analysing temperature, precipitation or humidity independently, the study approaches the regional climate system as an interconnected network.

The main research question is:

> **Has the structure of information transfer among climate variables changed over time in Southeastern Türkiye?**

---

## Study Area

The study focuses on **Southeastern Türkiye**, a region characterized by strong climatic gradients, semi-arid conditions and increasing exposure to climate-related risks.

The region is particularly suitable for investigating changes in interactions between:

- Temperature
- Precipitation
- Relative Humidity
- Wind Speed
- Solar Radiation
- Evapotranspiration

---

## Data Source

Monthly climate data are obtained from the **NASA POWER** project.

**Temporal coverage:** 1981–2025

**Temporal resolution:** Monthly

### Climate Variables

| Variable | Description |
|---|---|
| T2M | Air Temperature |
| PRECTOTCORR | Precipitation |
| RH2M | Relative Humidity |
| WS2M | Wind Speed |
| ALLSKY_SFC_SW_DWN | Solar Radiation |
| ET0 | Reference Evapotranspiration |

---

# Methodological Framework

The analysis follows a climate-network framework:

```text
NASA POWER Data
       │
       ▼
Data Cleaning & Quality Control
       │
       ▼
Monthly Climate Series
       │
       ▼
Stationarity & Preprocessing
       │
       ├───────────────┐
       ▼               ▼
Granger Causality   Transfer Entropy
       │               │
       └───────┬───────┘
               ▼
       Causal Climate Network
               │
               ▼
     Temporal Network Analysis
               │
               ▼
   1981–2000 vs. 2001–2025
               │
               ▼
      Climate System Reorganization
