# ------------------------------------------------------------------------------
# 1. Gerekli Paketlerin Y??klenmesi
# ------------------------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, viridis)

# ------------------------------------------------------------------------------
# 2. Saf R ile Y??ksek H??zl?? Shannon Transfer Entropisi Fonksiyonu
# ------------------------------------------------------------------------------
calc_shannon_te <- function(x, y, k = 1, l = 1, n_bins = 5) {
  # NA Temizli??i
  valid_idx <- complete.cases(x, y)
  x <- x[valid_idx]
  y <- y[valid_idx]
  
  N <- length(x)
  if (N <= max(k, l) + 10) return(c(TE_xy = NA, TE_yx = NA))
  
  # Verileri sembolik k??melere (Bins) ay??rma (Quantile Discretization)
  x_b <- as.numeric(cut(x, breaks = quantile(x, probs = seq(0, 1, length.out = n_bins + 1)), include.lowest = TRUE))
  y_b <- as.numeric(cut(y, breaks = quantile(y, probs = seq(0, 1, length.out = n_bins + 1)), include.lowest = TRUE))
  
  # Gecikmeli Seriler (Lagged Series)
  y_next <- y_b[(max(k,l)+1):N]
  y_past <- y_b[(max(k,l)):(N-1)]
  x_past <- x_b[(max(k,l)):(N-1)]
  
  x_next <- x_b[(max(k,l)+1):N]
  
  # Entropy Fonksiyonu: H(A)
  get_entropy <- function(mat) {
    p <- table(as.data.frame(mat)) / nrow(mat)
    p <- p[p > 0]
    -sum(p * log2(p))
  }
  
  # TE(X -> Y) = H(Y_next, Y_past) + H(Y_past, X_past) - H(Y_next, Y_past, X_past) - H(Y_past)
  H_ypast <- get_entropy(cbind(y_past))
  H_ynext_ypast <- get_entropy(cbind(y_next, y_past))
  H_ypast_xpast <- get_entropy(cbind(y_past, x_past))
  H_all_y <- get_entropy(cbind(y_next, y_past, x_past))
  
  TE_xy <- max(0, H_ynext_ypast + H_ypast_xpast - H_all_y - H_ypast)
  
  # TE(Y -> X)
  H_xpast <- get_entropy(cbind(x_past))
  H_xnext_xpast <- get_entropy(cbind(x_next, x_past))
  H_xpast_ypast <- H_ypast_xpast
  H_all_x <- get_entropy(cbind(x_next, x_past, y_past))
  
  TE_yx <- max(0, H_xnext_xpast + H_xpast_ypast - H_all_x - H_xpast)
  
  return(c(TE_xy = TE_xy, TE_yx = TE_yx))
}

# ------------------------------------------------------------------------------
# 3. Dura??an Verinin Haz??rlanmas??
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
# 4. 9 ??l ve ??iftler ????in Y??nl?? Ak???? Hesaplama D??ng??s??
# ------------------------------------------------------------------------------
calc_directional_te_city <- function(df_city, city_name) {
  clean_df <- df_city %>% drop_na()
  
  pairs <- list(
    c("temp_mean", "rh_mean"),
    c("temp_mean", "et0_tot"),
    c("et0_tot", "precip_tot"),
    c("rad_mean", "temp_mean"),
    c("wind_mean", "et0_tot"),
    c("rh_mean", "precip_tot")
  )
  
  results <- list()
  
  for (pair in pairs) {
    var_x <- pair[1]
    var_y <- pair[2]
    
    x_vec <- clean_df[[var_x]]
    y_vec <- clean_df[[var_y]]
    
    te_vals <- calc_shannon_te(x_vec, y_vec, k = 1, l = 1, n_bins = 5)
    
    te_xy <- te_vals["TE_xy"]
    te_yx <- te_vals["TE_yx"]
    net_flow <- te_xy - te_yx
    
    dominant_direction <- case_when(
      net_flow > 0.01 ~ paste0(var_x, " ---> ", var_y),
      net_flow < -0.01 ~ paste0(var_y, " ---> ", var_x),
      TRUE ~ "Symmetric / Bidirectional"
    )
    
    results[[length(results) + 1]] <- tibble(
      City = city_name,
      Var_X = var_x,
      Var_Y = var_y,
      TE_X_to_Y = round(te_xy, 4),
      TE_Y_to_X = round(te_yx, 4),
      Net_Information_Flow = round(net_flow, 4),
      Dominant_Direction = dominant_direction
    )
  }
  
  bind_rows(results)
}

# 9 ??ehir ????in Hesaplama
provinces <- unique(gap_stat$city)

te_results_all <- map_dfr(
  provinces,
  ~calc_directional_te_city(gap_stat %>% dplyr::filter(city == .x), .x)
)

# Tabloyu Kaydet
write_csv(te_results_all, "Table_Transfer_Entropy_9Provinces_EN.csv")
message(">>> Transfer Entropy calculations finished! Saved to Table_Transfer_Entropy_9Provinces_EN.csv")

# ------------------------------------------------------------------------------
# 5. G??rselle??tirme: Net Information Flow Heatmap (English)
# ------------------------------------------------------------------------------
te_results_all <- te_results_all %>%
  mutate(Pair = paste(Var_X, "<--->", Var_Y))

p_te_net <- ggplot(te_results_all, aes(x = City, y = Pair, fill = Net_Information_Flow)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.3f", Net_Information_Flow)), color = "black", size = 3, fontface = "bold") +
  scale_fill_gradient2(
    low = "#d7191c", 
    mid = "#ffffbf", 
    high = "#2b83ba", 
    midpoint = 0,
    name = "Net Flow\n(TE_xy - TE_yx)"
  ) +
  theme_minimal(base_size = 12) +
  labs(
    title = "Net Directional Information Flow Across 9 GAP Provinces",
    subtitle = "Positive values (Blue) indicate X ---> Y flow; Negative values (Red) indicate Y ---> X flow.",
    x = "Province / City",
    y = "Climate Variable Pair (X <---> Y)"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, face = "bold"),
    axis.text.y = element_text(face = "bold"),
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "right"
  )

print(p_te_net)
ggsave("Figure_Transfer_Entropy_NetFlow_EN.png", p_te_net, width = 11, height = 7, dpi = 300)