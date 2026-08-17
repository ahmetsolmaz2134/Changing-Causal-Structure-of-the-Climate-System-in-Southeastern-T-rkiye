# ------------------------------------------------------------------------------
# 1. Gerekli Paketlerin Y??klenmesi
# ------------------------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, vars, lmtest)

# ------------------------------------------------------------------------------
# 2. Dura??an Veri Setinin Temizlenerek Olu??turulmas??
# ------------------------------------------------------------------------------
if (!exists("gap_monthly")) {
  gap_monthly <- read_csv("GAP_Climate_Monthly_1990_2025.csv")
}

# Deseasonalize + Detrend + Z-score Normalization (NA & NaN Korumal??)
gap_stat <- gap_monthly %>%
  arrange(city, year, month) %>%
  pivot_longer(
    cols = c(temp_mean, precip_tot, rh_mean, wind_mean, rad_mean, et0_tot),
    names_to = "variable",
    values_to = "value"
  ) %>%
  group_by(city, variable) %>%
  mutate(
    monthly_mean = mean(value, na.rm = TRUE),
    deseasonalized = value - monthly_mean,
    time_idx = row_number(),
    detrended_resid = residuals(lm(deseasonalized ~ time_idx, na.action = na.exclude)),
    stationary_series = as.vector(scale(detrended_resid))
  ) %>%
  dplyr::select(city, year, month, variable, stationary_series) %>%
  pivot_wider(names_from = variable, values_from = stationary_series) %>%
  ungroup()

# ------------------------------------------------------------------------------
# 3. NA / Inf Ar??nd??r??lm???? Granger Nedensellik Fonksiyonu
# ------------------------------------------------------------------------------
run_physical_granger <- function(df_city, city_name) {
  
  # NA, NaN ve Inf i??eren sat??rlar?? tamamen temizle
  clean_df <- df_city %>%
    dplyr::select(temp_mean, precip_tot, rh_mean, wind_mean, rad_mean, et0_tot) %>%
    drop_na() %>%
    filter_all(all_vars(!is.infinite(.)))
  
  var_data <- as.matrix(clean_df)
  
  # Veri noktas?? kontrol?? (yeterli g??zlem var m???)
  if (nrow(var_data) < 24) {
    warning(paste("Yetersiz veri:", city_name))
    return(NULL)
  }
  
  # Optimal Lag Selection (Hata korumal?? tryCatch)
  opt_lag <- tryCatch({
    lag_select <- VARselect(var_data, lag.max = 12, type = "none")
    max(1, as.numeric(lag_select$selection["AIC(n)"]))
  }, error = function(e) {
    return(2) # Varsay??lan gecikme (lag=2)
  })
  
  pairs <- list(
    c("temp_mean", "et0_tot"),
    c("temp_mean", "rh_mean"),
    c("precip_tot", "rh_mean"),
    c("rad_mean", "temp_mean"),
    c("wind_mean", "et0_tot")
  )
  
  results <- list()
  for (pair in pairs) {
    cause_var <- pair[1]
    effect_var <- pair[2]
    
    # Granger testi i??in zaman serisi ??iftini ve NA kontrol??n?? yap
    pair_data <- var_data[, c(effect_var, cause_var)]
    
    g_test <- tryCatch({
      grangertest(
        pair_data[, 1] ~ pair_data[, 2],
        order = opt_lag
      )
    }, error = function(e) return(NULL))
    
    if (!is.null(g_test)) {
      results[[length(results) + 1]] <- tibble(
        City = city_name,
        Cause = cause_var,
        Effect = effect_var,
        Optimal_Lag = opt_lag,
        F_Stat = round(g_test$F[2], 3),
        p_value = round(g_test$`Pr(>F)`[2], 4),
        Is_Significant = ifelse(g_test$`Pr(>F)`[2] < 0.05, "Yes", "No")
      )
    }
  }
  bind_rows(results)
}

# ------------------------------------------------------------------------------
# 4. Analizin ??al????t??r??lmas?? ve Kaydedilmesi
# ------------------------------------------------------------------------------
granger_physical_results <- map_dfr(
  unique(gap_stat$city), 
  ~run_physical_granger(gap_stat %>% dplyr::filter(city == .x), .x)
)

# ????kt??y?? Kaydet
write_csv(granger_physical_results, "Table_Granger_Physical_9Provinces.csv")
message(">>> NA/Inf Hatalar?? Temizlendi. Fiziksel Granger Analizi Ba??ar??yla Tamamland??!")