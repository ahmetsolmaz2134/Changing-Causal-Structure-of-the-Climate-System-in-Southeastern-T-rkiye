# ------------------------------------------------------------------------------
# 1. Gerekli Paketler
# ------------------------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, igraph, ggraph, viridis, tidygraph)

# ------------------------------------------------------------------------------
# 2. H??zl?? Transfer Entropy ??ekirdek Fonksiyonu (Standalone)
# ------------------------------------------------------------------------------
calc_single_te <- function(x, y, n_bins = 5) {
  valid_idx <- complete.cases(x, y)
  x <- x[valid_idx]
  y <- y[valid_idx]
  N <- length(x)
  if (N <= 12) return(0)
  
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
  
  H_ypast <- get_entropy(cbind(y_past))
  H_ynext_ypast <- get_entropy(cbind(y_next, y_past))
  H_ypast_xpast <- get_entropy(cbind(y_past, x_past))
  H_all <- get_entropy(cbind(y_next, y_past, x_past))
  
  te_val <- H_ynext_ypast + H_ypast_xpast - H_all - H_ypast
  return(max(0, te_val))
}

# ------------------------------------------------------------------------------
# 3. T??m De??i??ken Kombinasyonlar?? ????in Master A????n Hesaplanmas??
# ------------------------------------------------------------------------------
# gap_stat verisinin haf??zada oldu??u varsay??lmaktad??r. 
# T??m illerin verisini birle??tirip b??lgesel bir sinyal ????kar??yoruz.

variables <- c("rad_mean", "temp_mean", "rh_mean", "et0_tot", "wind_mean", "precip_tot")
edge_list <- list()

message(">>> B??lgesel Master ??klim A???? i??in Transfer Entropy hesaplan??yor...")

for (i in 1:(length(variables) - 1)) {
  for (j in (i + 1):length(variables)) {
    var1 <- variables[i]
    var2 <- variables[j]
    
    # T??m GAP b??lgesi verisini zaman serisi olarak u?? uca ekleyerek b??lgesel dinamik elde etme
    # (veya illerin ortalamas?? al??nabilir. Burada b??lgesel g????l?? sinyal i??in havuzlama yap??yoruz)
    x_vec <- gap_stat[[var1]]
    y_vec <- gap_stat[[var2]]
    
    te_1_to_2 <- calc_single_te(x_vec, y_vec)
    te_2_to_1 <- calc_single_te(y_vec, x_vec)
    
    net_flow <- te_1_to_2 - te_2_to_1
    
    # Sadece anlaml?? bir ak???? varsa (??rn: Net TE > 0.005) a??a ekle
    if (net_flow > 0.005) {
      edge_list[[length(edge_list) + 1]] <- tibble(from = var1, to = var2, weight = net_flow)
    } else if (net_flow < -0.005) {
      edge_list[[length(edge_list) + 1]] <- tibble(from = var2, to = var1, weight = abs(net_flow))
    }
  }
}

edges_df <- bind_rows(edge_list)

# D??????m ??simlerini Akademik Formata ??evirme
node_labels <- c(
  "rad_mean" = "Radiation", 
  "temp_mean" = "Temperature", 
  "rh_mean" = "Humidity", 
  "et0_tot" = "ET0", 
  "wind_mean" = "Wind", 
  "precip_tot" = "Precipitation"
)

edges_df <- edges_df %>%
  mutate(
    from = node_labels[from],
    to = node_labels[to]
  )

# ------------------------------------------------------------------------------
# 4. Hiyerar??ik A?? (Sugiyama DAG) G??rselle??tirmesi
# ------------------------------------------------------------------------------
# Y??nl?? A?? Objesini Olu??turma
climate_graph <- as_tbl_graph(edges_df, directed = TRUE)

# Sugiyama algoritmas?? otomatik olarak Radyasyonu tepeye, Ya???????? a??a????ya iten
# bir hiyerar??i (Directed Acyclic Graph) kurar.
p_network <- ggraph(climate_graph, layout = "sugiyama") +
  # Oklar ve Ba??lant??lar (Kal??nl??k = TE G??c??)
  geom_edge_diagonal(
    aes(width = weight, color = weight),
    arrow = arrow(length = unit(5, 'mm'), type = "closed"), 
    end_cap = circle(10, 'mm'), 
    alpha = 0.85
  ) +
  # D??????mler
  geom_node_point(size = 18, color = "#2c3e50", alpha = 0.9) +
  # D??????m Etiketleri
  geom_node_text(aes(label = name), color = "white", fontface = "bold", size = 4.5) +
  # Renk ve Kal??nl??k Skalalar??
  scale_edge_width_continuous(range = c(0.8, 4), name = "Net Info Flow (TE)") +
  scale_edge_color_viridis(option = "magma", direction = -1, name = "Net Info Flow (TE)") +
  theme_void(base_size = 14) +
  labs(
    title = "Causal Climate Network (Information Flow) in GAP Region",
    subtitle = "Nodes represent climate variables. Directed edges represent the net direction of Information Transfer (Transfer Entropy).\nEdge thickness corresponds to the strength of causality.",
    caption = "Computed via Shannon Transfer Entropy Network Analysis"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray20"),
    plot.caption = element_text(size = 9, color = "gray40", face = "italic"),
    legend.position = "bottom",
    legend.key.width = unit(2, "cm")
  )

print(p_network)
ggsave("Figure_Master_Causal_Climate_Network_EN.png", p_network, width = 10, height = 9, dpi = 300)
message(">>> Master A?? G??rseli Kaydedildi: Figure_Master_Causal_Climate_Network_EN.png")