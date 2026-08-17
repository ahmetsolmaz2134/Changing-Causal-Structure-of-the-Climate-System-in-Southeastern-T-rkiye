library(tidyverse)
library(zoo)
library(patchwork)

# 1. Verinin Okunmas?? ve Zaman Serisi Metriklerinin T??retilmesi
gap_monthly <- read_csv("GAP_Climate_Monthly_1990_2025.csv")

climate_variability <- gap_monthly %>%
  arrange(city, date) %>%
  pivot_longer(
    cols = c(temp_mean, precip_tot, rh_mean, wind_mean, rad_mean, et0_tot),
    names_to = "variable",
    values_to = "value"
  ) %>%
  group_by(city, variable) %>%
  # 12-Ayl??k Hareketli Ortalama (12-Month Moving Average)
  mutate(
    roll_mean_12 = rollmean(value, k = 12, fill = NA, align = "right")
  ) %>%
  # Uzun Y??llar Ay Bazl?? ??klim Normalleri (1990-2025 Baseline)
  group_by(city, variable, month) %>%
  mutate(
    monthly_clim_mean = mean(value, na.rm = TRUE),
    monthly_clim_sd   = sd(value, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  # Anomali ve Standartla??t??r??lm???? Seri (Z-Score)
  mutate(
    anomaly = value - monthly_clim_mean,
    standardized_anomaly = ifelse(monthly_clim_sd > 0, (value - monthly_clim_mean) / monthly_clim_sd, 0)
  )

# ??ngilizce Akademik Etiketler
var_labels <- c(
  "temp_mean"  = "Mean Temperature (??C)",
  "precip_tot" = "Total Precipitation (mm)",
  "rh_mean"    = "Relative Humidity (%)",
  "wind_mean"  = "Wind Speed (m/s)",
  "rad_mean"   = "Solar Radiation (MJ/m??/day)",
  "et0_tot"    = "Reference Evapotranspiration - ET0 (mm)"
)

climate_variability <- climate_variability %>%
  mutate(var_label = factor(variable, levels = names(var_labels), labels = var_labels))