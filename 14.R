# ------------------------------------------------------------------------------
# 1. Paket Tan??mlar?? ve Grafik Ayg??t?? S??f??rlama
# ------------------------------------------------------------------------------
graphics.off() # Grafik s??r??c??s??n?? temizle

if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, igraph, tidygraph, Kendall, zyp, patchwork, viridis)

# ------------------------------------------------------------------------------
# 2. Kur??un Ge??irmez Transfer Entropy ??ekirdek Fonksiyonu
# ------------------------------------------------------------------------------
calc_single_te_robust <- function(x, y, n_bins = 5, lag = 1) {
  # Eksik veri temizli??i
  valid_idx <- complete.cases(x, y)
  x <- x[valid_idx]
  y <- y[valid_idx]
  
  N <- length(x)
  # Veri boyutu kontrol?? (n <= lag veya yetersiz g??zlem durumunda 0 d??nd??r)
  if (N <= (lag + 10)) return(0)
  
  # Quantile b??lme i??lemlerinde ??ak????malar?? (non-unique breaks) ??nleme
  x_q <- tryCatch(quantile(x, probs = seq(0, 1, length.out = n_bins + 1)), error = function(e) NULL)
  y_q <- tryCatch(quantile(y, probs = seq(0, 1, length.out = n_bins + 1)), error = function(e) NULL)
  
  if (is.null(x_q) || is.null(y_q) || length(unique(x_q)) != length(x_q) || length(unique(y_q)) != length(y_q)) {
    return(0)
  }
  
  x_b <- as.numeric(cut(x, breaks = x_q, include.lowest = TRUE))
  y_b <- as.numeric(cut(y, breaks = y_q, include.lowest = TRUE))
  
  # Gecikmeli seriler (G??venli Dilimleme)
  y_next <- y_b[(lag + 1):N]
  y_past <- y_b[1:(N - lag)]
  x_past <- x_b[1:(N - lag)]
  
  get_entropy <- function(mat) {
    p <- table(as.data.frame(mat)) / nrow(mat)
    p <- p[p > 0]
    -sum(p * log2(p))
  }
  
  H_ypast       <- get_entropy(cbind(y_past))
  H_ynext_ypast <- get_entropy(cbind(y_next, y_past))
  H_ypast_xpast <- get_entropy(cbind(y_past, x_past))
  H_all         <- get_entropy(cbind(y_next, y_past, x_past))
  
  te_val <- H_ynext_ypast + H_ypast_xpast - H_all - H_ypast
  return(max(0, te_val))
}

# ------------------------------------------------------------------------------
# 3. Zamansal A?? Metriklerinin Hesaplanmas??
# ------------------------------------------------------------------------------
min_yr <- min(gap_stat$year, na.rm = TRUE)
max_yr <- max(gap_stat$year, na.rm = TRUE)
window_size <- 15
step_size   <- 3

start_years <- seq(min_yr, max_yr - window_size + 1, by = step_size)
variables   <- c("rad_mean", "temp_mean", "rh_mean", "et0_tot", "wind_mean", "precip_tot")
node_names  <- c("Radiation", "Temperature", "Humidity", "ET0", "Wind", "Precipitation")
label_map   <- setNames(node_names, variables)

global_struct_list <- list()
node_struct_list   <- list()

message(">>> Network Structural Change Analizi Y??r??t??l??yor...")

for (sy in start_years) {
  ey <- sy + window_size - 1
  win_label <- paste0(sy, "-", ey)
  mid_year  <- sy + (window_size / 2)
  
  win_df <- gap_stat %>% filter(year >= sy & year <= ey)
  edge_list <- list()
  
  for (i in 1:(length(variables) - 1)) {
    for (j in (i + 1):length(variables)) {
      v1 <- variables[i]; v2 <- variables[j]
      
      te_12 <- calc_single_te_robust(win_df[[v1]], win_df[[v2]])
      te_21 <- calc_single_te_robust(win_df[[v2]], win_df[[v1]])
      
      net_flow <- te_12 - te_21
      
      if (abs(net_flow) > 0.0001) {
        if (net_flow > 0) {
          edge_list[[length(edge_list) + 1]] <- tibble(from = label_map[v1], to = label_map[v2], weight = net_flow)
        } else {
          edge_list[[length(edge_list) + 1]] <- tibble(from = label_map[v2], to = label_map[v1], weight = abs(net_flow))
        }
      }
    }
  }
  
  edges_df <- bind_rows(edge_list)
  nodes_df <- tibble(name = node_names)
  g <- tbl_graph(nodes = nodes_df, edges = edges_df, directed = TRUE)
  
  dens     <- edge_density(g)
  avg_flow <- if (ecount(g) > 0) mean(E(g)$weight) else 0
  
  global_struct_list[[win_label]] <- tibble(
    Window = win_label,
    Mid_Year = mid_year,
    Network_Density = dens,
    Mean_Info_Flow = avg_flow
  )
  
  node_struct_list[[win_label]] <- tibble(
    Window = win_label,
    Mid_Year = mid_year,
    Variable = V(g)$name,
    Out_Degree = degree(g, mode = "out"),
    Betweenness_Centrality = betweenness(g, normalized = TRUE)
  )
}

df_global_struct <- bind_rows(global_struct_list)
df_node_struct   <- bind_rows(node_struct_list)

# ------------------------------------------------------------------------------
# 4. G??rselle??tirme (Ekrana ??izme + Dosya Kayd??)
# ------------------------------------------------------------------------------
p_a <- ggplot(df_global_struct, aes(x = Mid_Year, y = Network_Density)) +
  geom_line(color = "#2b83ba", linewidth = 1.1) +
  geom_point(color = "#2b83ba", size = 2.5) +
  geom_smooth(method = "lm", se = FALSE, linetype = "dashed", color = "#1a5276") +
  theme_minimal(base_size = 11) +
  labs(title = "A) Network Density Evolution", x = "Mid-Period Year", y = "Density") +
  theme(plot.title = element_text(face = "bold"))

p_b <- ggplot(df_global_struct, aes(x = Mid_Year, y = Mean_Info_Flow)) +
  geom_line(color = "#d7191c", linewidth = 1.1) +
  geom_point(color = "#d7191c", size = 2.5) +
  geom_smooth(method = "lm", se = FALSE, linetype = "dashed", color = "#990000") +
  theme_minimal(base_size = 11) +
  labs(title = "B) Mean Info Flow Strength (Net TE)", x = "Mid-Period Year", y = "Mean Net TE (bits)") +
  theme(plot.title = element_text(face = "bold"))

p_c <- ggplot(df_node_struct, aes(x = Mid_Year, y = Betweenness_Centrality, color = Variable)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_color_brewer(palette = "Set1") +
  theme_minimal(base_size = 11) +
  labs(title = "C) Betweenness Centrality Shifts", x = "Mid-Period Year", y = "Betweenness", color = "Variable") +
  theme(plot.title = element_text(face = "bold"))

p_d <- ggplot(df_node_struct, aes(x = Mid_Year, y = Out_Degree, color = Variable)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_color_brewer(palette = "Set1") +
  theme_minimal(base_size = 11) +
  labs(title = "D) Out-Degree Dynamics (Driver Power)", x = "Mid-Period Year", y = "Out-Degree", color = "Variable") +
  theme(plot.title = element_text(face = "bold"))

# Panel Birle??tirme
p_struct_master <- (p_a | p_b) / (p_c | p_d) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title = "Structural Dynamics of the Causal Climate Network",
    subtitle = "Tracking network density, information strength, and centrality shifts over time.",
    theme = theme(plot.title = element_text(face = "bold", size = 14, hjust = 0.5))
  )

# Grafik S??r??c??s??n?? Zorla A????p Ekrana Basma
dev.new() 
print(p_struct_master)

# Y??ksek ????z??n??rl??kl?? Kay??t
ggsave("Figure_Network_Structural_Change_Dynamics_EN.png", p_struct_master, width = 12, height = 9, dpi = 300)
message(">>> Grafik ekrana bas??ld?? ve 'Figure_Network_Structural_Change_Dynamics_EN.png' olarak kaydedildi!")