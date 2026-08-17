# ------------------------------------------------------------------------------
# 1. Gerekli Paketler
# ------------------------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, igraph, tidygraph, viridis, patch)

# ------------------------------------------------------------------------------
# 2. Dura??an Veri Kontrol??
# ------------------------------------------------------------------------------
if (!exists("gap_stat")) {
  stop("L??tfen ??ncelikle 'gap_stat' dura??anla??t??r??lm???? iklim veri ??er??evsini y??kleyin.")
}

# ------------------------------------------------------------------------------
# 3. Transfer Entropy ??ekirdek Fonksiyonu
# ------------------------------------------------------------------------------
calc_single_te <- function(x, y, n_bins = 5) {
  valid_idx <- complete.cases(x, y)
  x <- x[valid_idx]; y <- y[valid_idx]
  N <- length(x)
  if (N <= 12) return(0)
  
  x_b <- as.numeric(cut(x, breaks = quantile(x, probs = seq(0, 1, length.out = n_bins + 1)), include.lowest = TRUE))
  y_b <- as.numeric(cut(y, breaks = quantile(y, probs = seq(0, 1, length.out = n_bins + 1)), include.lowest = TRUE))
  
  y_next <- y_b[2:N]; y_past <- y_b[1:(N-1)]; x_past <- x_b[1:(N-1)]
  
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
# 4. Hareketli Zaman Pencerelerinin Olu??turulmas?? (Sliding Windows)
# ------------------------------------------------------------------------------
min_yr <- min(gap_stat$year, na.rm = TRUE)
max_yr <- max(gap_stat$year, na.rm = TRUE)

window_size <- 15 # 15 Y??ll??k Pencere
step_size <- 5    # 5 Y??ll??k Ad??m

start_years <- seq(min_yr, max_yr - window_size + 1, by = step_size)

variables <- c("rad_mean", "temp_mean", "rh_mean", "et0_tot", "wind_mean", "precip_tot")
node_names <- c("Radiation", "Temperature", "Humidity", "ET0", "Wind", "Precipitation")
label_map  <- setNames(node_names, variables)

temporal_metrics <- list()
temporal_edges   <- list()

message(">>> Temporal Network Analysis Ba??lat??l??yor...")

for (sy in start_years) {
  ey <- sy + window_size - 1
  win_label <- paste0(sy, "-", ey)
  message(paste("   Analiz Edilen Pencere:", win_label))
  
  win_df <- gap_stat %>% filter(year >= sy & year <= ey)
  edge_list <- list()
  
  for (i in 1:(length(variables) - 1)) {
    for (j in (i + 1):length(variables)) {
      var1 <- variables[i]
      var2 <- variables[j]
      
      te_12 <- calc_single_te(win_df[[var1]], win_df[[var2]])
      te_21 <- calc_single_te(win_df[[var2]], win_df[[var1]])
      
      net_flow <- te_12 - te_21
      
      if (abs(net_flow) > 0.0001) {
        if (net_flow > 0) {
          edge_list[[length(edge_list) + 1]] <- tibble(from = label_map[var1], to = label_map[var2], weight = net_flow)
        } else {
          edge_list[[length(edge_list) + 1]] <- tibble(from = label_map[var2], to = label_map[var1], weight = abs(net_flow))
        }
      }
    }
  }
  
  edges_df <- bind_rows(edge_list)
  nodes_df <- tibble(name = node_names)
  
  g <- tbl_graph(nodes = nodes_df, edges = edges_df, directed = TRUE)
  
  # Pencere Bazl?? Metrikler
  dens <- edge_density(g)
  out_deg <- degree(g, mode = "out")
  btw <- betweenness(g, normalized = TRUE)
  
  temporal_metrics[[win_label]] <- tibble(
    Window = win_label,
    Period_Center = sy + (window_size / 2),
    Density = dens,
    Variable = V(g)$name,
    Out_Degree = out_deg,
    Betweenness = btw
  )
}

temp_res <- bind_rows(temporal_metrics)

# CSV Olarak Kaydet
write_csv(temp_res, "Table_Temporal_Network_Metrics_Evolution.csv")
message(">>> Zamansal a?? metrikleri kaydedildi: Table_Temporal_Network_Metrics_Evolution.csv")

# ------------------------------------------------------------------------------
# 5. Zamansal De??i??im Grafikleri (Temporal Dynamics Plots)
# ------------------------------------------------------------------------------
# A) A?? Yo??unlu??unun Zamansal Evrimi (Network Coupling)
p1 <- ggplot(temp_res %>% distinct(Window, Period_Center, Density), aes(x = Period_Center, y = Density)) +
  geom_line(color = "#2b83ba", linewidth = 1.2) +
  geom_point(color = "#2b83ba", size = 3) +
  theme_minimal(base_size = 12) +
  labs(
    title = "A) Evolution of Overall Climate Network Density",
    subtitle = "Higher density indicates stronger coupling among regional climate variables.",
    x = "Mid-Period Year",
    y = "Network Density"
  ) +
  theme(plot.title = element_text(face = "bold"))

# B) S??r??c?? De??i??kenlerin (Out-Degree / Causal Drivers) Zamansal De??i??imi
p2 <- ggplot(temp_res, aes(x = Period_Center, y = Out_Degree, color = Variable, group = Variable)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_color_brewer(palette = "Set1") +
  theme_minimal(base_size = 12) +
  labs(
    title = "B) Shifts in Causal Driver Power (Out-Degree)",
    subtitle = "Tracking which variable controls the climate dynamic over sliding 15-year windows.",
    x = "Mid-Period Year",
    y = "Out-Degree (Information Output)",
    color = "Variable"
  ) +
  theme(plot.title = element_text(face = "bold"), legend.position = "right")

# Grafikleri Birle??tirme ve Kaydetme
p_temporal_combined <- p1 / p2
print(p_temporal_combined)

ggsave("Figure_Temporal_Network_Dynamics_EN.png", p_temporal_combined, width = 10, height = 9, dpi = 300)
message(">>> Zamansal A?? Evrimi Grafi??i Kaydedildi: Figure_Temporal_Network_Dynamics_EN.png")