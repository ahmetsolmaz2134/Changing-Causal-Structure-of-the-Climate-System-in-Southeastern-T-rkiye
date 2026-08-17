# ------------------------------------------------------------------------------
# 1. Gerekli Paketler
# ------------------------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, igraph, ggraph, viridis, tidygraph)

# ------------------------------------------------------------------------------
# 2. Dura??an Veri Kontrol?? ve Haz??rl??????
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
# 3. Transfer Entropy Hesaplama Fonksiyonu
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
# 4. T??m ??iftler ????in Transfer Entropisi ve Net Ak???? Hesab??
# ------------------------------------------------------------------------------
variables <- c("rad_mean", "temp_mean", "rh_mean", "et0_tot", "wind_mean", "precip_tot")
node_names <- c("Radiation", "Temperature", "Humidity", "ET0", "Wind", "Precipitation")

nodes_df <- tibble(name = node_names)
edge_list <- list()

for (i in 1:(length(variables) - 1)) {
  for (j in (i + 1):length(variables)) {
    var1 <- variables[i]
    var2 <- variables[j]
    
    te_12 <- calc_single_te(gap_stat[[var1]], gap_stat[[var2]])
    te_21 <- calc_single_te(gap_stat[[var2]], gap_stat[[var1]])
    
    net_flow <- te_12 - te_21
    
    if (abs(net_flow) > 0.0001) { # Esnek e??ik
      if (net_flow > 0) {
        edge_list[[length(edge_list) + 1]] <- tibble(from = var1, to = var2, weight = net_flow)
      } else {
        edge_list[[length(edge_list) + 1]] <- tibble(from = var2, to = var1, weight = abs(net_flow))
      }
    }
  }
}

edges_df <- bind_rows(edge_list)

# ??simleri De??i??tirme
label_map <- setNames(node_names, variables)
edges_df <- edges_df %>%
  mutate(from = label_map[from], to = label_map[to])

# ------------------------------------------------------------------------------
# 5. Garanti A?? Objesinin (tbl_graph) Olu??turulmas??
# ------------------------------------------------------------------------------
climate_graph <- tbl_graph(nodes = nodes_df, edges = edges_df, directed = TRUE)

# ------------------------------------------------------------------------------
# 6. Hiyerar??ik G??rselle??tirme (Garantili Layout)
# ------------------------------------------------------------------------------
p_network <- ggraph(climate_graph, layout = "nicely") +
  geom_edge_link(
    aes(width = weight, color = weight),
    arrow = arrow(length = unit(4, 'mm'), type = "closed"), 
    end_cap = circle(8, 'mm'),
    alpha = 0.8
  ) +
  geom_node_point(size = 16, color = "#1f77b4") +
  geom_node_text(aes(label = name), color = "white", fontface = "bold", size = 3.8) +
  scale_edge_width_continuous(range = c(0.8, 3.5), name = "Net Info Flow") +
  scale_edge_color_viridis(option = "magma", name = "Net Info Flow") +
  theme_void(base_size = 12) +
  labs(
    title = "Causal Climate Network (Information Flow) - GAP Region",
    subtitle = "Arrows indicate the net direction of information flow between variables.",
    caption = "Computed via Shannon Transfer Entropy"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5),
    legend.position = "bottom"
  )

# Ekran ????kt??s?? ve Dosyaya Kaydetme
dev.new() # Yeni pencere a??arak ??izim alan??n?? s??f??rlar
print(p_network)
ggsave("Figure_Master_Causal_Climate_Network_EN.png", p_network, width = 9, height = 8, dpi = 300)

message(">>> A?? grafi??i ekrana bas??ld?? ve Figure_Master_Causal_Climate_Network_EN.png olarak kaydedildi!")