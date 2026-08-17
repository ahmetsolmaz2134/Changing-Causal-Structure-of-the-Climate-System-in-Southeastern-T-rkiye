# ------------------------------------------------------------------------------
# 1. Gerekli Paketlerin Y??klenmesi
# ------------------------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, viridis)

# ------------------------------------------------------------------------------
# 2. Dura??an Verinin Haz??rlanmas?? (E??er yoksa)
# ------------------------------------------------------------------------------
if (!exists("gap_monthly")) {
  gap_monthly <- read_csv("GAP_Climate_Monthly_1990_2025.csv")
}

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
# 3. Shannon Transfer Entropy ??ekirdek Fonksiyonu
# ------------------------------------------------------------------------------
calc_single_te <- function(x, y, n_bins = 5) {
  valid_idx <- complete.cases(x, y)
  x <- x[valid_idx]
  y <- y[valid_idx]
  N <- length(x)
  if (N <= 12) return(NA)
  
  # Quantile Discretization
  x_b <- as.numeric(cut(x, breaks = quantile(x, probs = seq(0, 1, length.out = n_bins + 1)), include.lowest = TRUE))
  y_b <- as.numeric(cut(y, breaks = quantile(y, probs = seq(0, 1, length.out = n_bins + 1)), include.lowest = TRUE))
  
  y_next <- y_b[2:N]
  y_past <- y_b[1:(N-1)]
  x_past <- x_b[1:(N-1)]
  
  get_entropy <- function(mat) {
    p <- table(as.data.frame(mat)) / nrow(mat)
    p <- p[p > 0]
    -sum(p * log2(p))
  }
  
  H_ypast       <- get_entropy(cbind(y_past))
  H_ynext_ypast <- get_entropy(cbind(y_next, y_past))
  H_ypast_xpast <- get_entropy(cbind(y_past, x_past))
  H_all         <- get_entropy(cbind(y_next, y_past, x_past))
  
  max(0, H_ynext_ypast + H_ypast_xpast - H_all - H_ypast)
}

# ------------------------------------------------------------------------------
# 4. Time-Shift Surrogate Testi ve Effective TE (ETE) Hesab??
# ------------------------------------------------------------------------------
run_surrogate_te_test <- function(x, y, n_surrogates = 200, min_shift = 12) {
  obs_te <- calc_single_te(x, y)
  if (is.na(obs_te)) return(list(obs_te = NA, ete = NA, z_score = NA, p_val = NA))
  
  N <- length(x)
  null_dist <- numeric(n_surrogates)
  
  for (i in 1:n_surrogates) {
    # Time-Shift (Dairesel Kayd??rma) - Otokorelasyon yap??s??n?? korur
    shift_val <- sample(min_shift:(N - min_shift), 1)
    x_surr <- c(x[(shift_val + 1):N], x[1:shift_val])
    null_dist[i] <- calc_single_te(x_surr, y)
  }
  
  mean_null <- mean(null_dist, na.rm = TRUE)
  sd_null <- sd(null_dist, na.rm = TRUE)
  
  # Effective Transfer Entropy (??rneklem sapmas??ndan ar??nd??r??lm???? net TE)
  ete <- obs_te - mean_null
  
  # Z-Skoru ve Monte Carlo p-de??eri
  z_score <- if (!is.na(sd_null) && sd_null > 0) (obs_te - mean_null) / sd_null else 0
  p_val <- (sum(null_dist >= obs_te, na.rm = TRUE) + 1) / (n_surrogates + 1)
  
  list(obs_te = obs_te, ete = ete, z_score = z_score, p_val = p_val)
}

# ------------------------------------------------------------------------------
# 5. 9 ??l ????in Analizin ??al????t??r??lmas?? (??rnek ??ift: Temp -> ET0)
# ------------------------------------------------------------------------------
message(">>> 9 ??l i??in Surrogate Transfer Entropy Analizi Ba??lat??l??yor...")

set.seed(42) # Tekrarlanabilirlik i??in
provinces <- unique(gap_stat$city)

surrogate_results <- map_dfr(provinces, function(city_name) {
  city_df <- gap_stat %>% filter(city == city_name) %>% drop_na()
  
  test_res <- run_surrogate_te_test(
    x = city_df$temp_mean, 
    y = city_df$et0_tot, 
    n_surrogates = 200
  )
  
  tibble(
    City = city_name,
    Cause = "temp_mean",
    Effect = "et0_tot",
    Observed_TE = round(test_res$obs_te, 4),
    Effective_TE = round(test_res$ete, 4),
    Z_Score = round(test_res$z_score, 2),
    p_value = round(test_res$p_val, 4),
    Is_Significant = ifelse(test_res$p_val < 0.05, "Significant (p < 0.05)", "Non-Significant")
  )
})

# Tabloyu Kaydet
write_csv(surrogate_results, "Table_Transfer_Entropy_Surrogate_Significance_9Provinces.csv")
message(">>> Analiz tamamland??. Kaydedilen dosya: Table_Transfer_Entropy_Surrogate_Significance_9Provinces.csv")

# ------------------------------------------------------------------------------
# 6. G??rselle??tirme: Z-Skoru ve Anlaml??l??k Grafi??i (English)
# ------------------------------------------------------------------------------
p_surr <- ggplot(surrogate_results, aes(x = reorder(City, Z_Score), y = Z_Score, fill = Is_Significant)) +
  geom_col(width = 0.6) +
  geom_hline(yintercept = 1.96, linetype = "dashed", color = "red", linewidth = 0.8) +
  coord_flip() +
  scale_fill_manual(values = c("Significant (p < 0.05)" = "#2b83ba", "Non-Significant" = "#d7191c")) +
  theme_minimal(base_size = 12) +
  labs(
    title = "Transfer Entropy Significance Test (Temp -> ET0)",
    subtitle = "Dashed red line indicates Z = 1.96 threshold (p = 0.05 level using Time-Shift Surrogates).",
    x = "Province / City",
    y = "Standardized Z-Score (Z > 1.96 indicates statistical significance)",
    fill = "Significance"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    legend.position = "bottom"
  )

print(p_surr)
ggsave("Figure_Transfer_Entropy_Surrogate_ZScore_EN.png", p_surr, width = 9, height = 6, dpi = 300)