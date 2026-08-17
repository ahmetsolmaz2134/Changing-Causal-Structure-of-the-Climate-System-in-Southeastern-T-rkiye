# ------------------------------------------------------------------------------
# 1. Gerekli Paketlerin Y??klenmesi
# ------------------------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, igraph, ggraph, viridis, tidygraph, patchwork)

# ------------------------------------------------------------------------------
# 2. Transfer Entropy ??ekirdek Fonksiyonu
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
# 3. ??ki D??nem ????in A??lar??n Olu??turulmas??
# ------------------------------------------------------------------------------
variables  <- c("rad_mean", "temp_mean", "rh_mean", "et0_tot", "wind_mean", "precip_tot")
node_names <- c("Radiation", "Temperature", "Humidity", "ET0", "Wind", "Precipitation")
label_map  <- setNames(node_names, variables)

# D??nem Tan??mlamalar??
# (Veri ba??lang??c??na g??re otomatik adapte olur)
min_data_yr <- min(gap_stat$year, na.rm = TRUE)
p1_start <- min_data_yr
p1_end   <- 2000
p2_start <- 2001
p2_end   <- max(gap_stat$year, na.rm = TRUE)

build_epoch_network <- function(df_subset, epoch_label) {
  edge_list <- list()
  for (i in 1:(length(variables) - 1)) {
    for (j in (i + 1):length(variables)) {
      v1 <- variables[i]; v2 <- variables[j]
      te_12 <- calc_single_te(df_subset[[v1]], df_subset[[v2]])
      te_21 <- calc_single_te(df_subset[[v2]], df_subset[[v1]])
      net_flow <- te_12 - te_21
      
      if (abs(net_flow) > 0.0001) {
        if (net_flow > 0) {
          edge_list[[length(edge_list) + 1]] <- tibble(
            from = label_map[v1], to = label_map[v2], weight = net_flow, Epoch = epoch_label
          )
        } else {
          edge_list[[length(edge_list) + 1]] <- tibble(
            from = label_map[v2], to = label_map[v1], weight = abs(net_flow), Epoch = epoch_label
          )
        }
      }
    }
  }
  bind_rows(edge_list)
}

df_p1 <- gap_stat %>% filter(year >= p1_start & year <= p1_end)
df_p2 <- gap_stat %>% filter(year >= p2_start & year <= p2_end)

edges_p1 <- build_epoch_network(df_p1, paste0(p1_start, "-", p1_end))
edges_p2 <- build_epoch_network(df_p2, paste0(p2_start, "-", p2_end))

# D??????m Tan??m??
nodes_df <- tibble(name = node_names)

g1 <- tbl_graph(nodes = nodes_df, edges = edges_p1, directed = TRUE)
g2 <- tbl_graph(nodes = nodes_df, edges = edges_p2, directed = TRUE)

# ------------------------------------------------------------------------------
# 4. Yan Yana Kar????la??t??rmal?? A?? G??rselle??tirmesi
# ------------------------------------------------------------------------------
# Sabit Dairesel D??zen (??ki grafikte d??????mler ayn?? yerde durur, k??yaslama kolayla????r)
layout_fixed <- create_layout(g1, layout = 'circle')

p_net1 <- ggraph(layout_fixed) +
  geom_edge_link(
    aes(width = weight, color = weight),
    arrow = arrow(length = unit(3.5, 'mm'), type = "closed"), 
    end_cap = circle(7, 'mm'), alpha = 0.85
  ) +
  geom_node_point(size = 14, color = "#2c3e50") +
  geom_node_text(aes(label = name), color = "white", fontface = "bold", size = 3) +
  scale_edge_width_continuous(range = c(0.8, 3.5), limits = c(0, 0.05), guide = "none") +
  scale_edge_color_viridis(option = "magma", limits = c(0, 0.05), guide = "none") +
  theme_void(base_size = 12) +
  labs(title = paste0("A) Historical Period (", p1_start, "-", p1_end, ")")) +
  theme(plot.title = element_text(face = "bold", hjust = 0.5, size = 13))

p_net2 <- ggraph(g2, layout = 'circle') +
  geom_edge_link(
    aes(width = weight, color = weight),
    arrow = arrow(length = unit(3.5, 'mm'), type = "closed"), 
    end_cap = circle(7, 'mm'), alpha = 0.85
  ) +
  geom_node_point(size = 14, color = "#27ae60") +
  geom_node_text(aes(label = name), color = "white", fontface = "bold", size = 3) +
  scale_edge_width_continuous(range = c(0.8, 3.5), limits = c(0, 0.05), name = "Net TE Strength") +
  scale_edge_color_viridis(option = "magma", limits = c(0, 0.05), name = "Net TE Strength") +
  theme_void(base_size = 12) +
  labs(title = paste0("B) Recent Period (", p2_start, "-", p2_end, ")")) +
  theme(plot.title = element_text(face = "bold", hjust = 0.5, size = 13))

# Grafikleri Yan Yana Birle??tirme
p_comparison <- (p_net1 | p_net2) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title = "Structural Shift in Causal Climate Network (Historical vs. Recent Epoch)",
    subtitle = "Comparison of net information flow pathways between climate variables across two eras.",
    theme = theme(
      plot.title = element_text(face = "bold", size = 15, hjust = 0.5),
      plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray20")
    )
  )

print(p_comparison)
ggsave("Figure_Epoch_Network_Comparison_EN.png", p_comparison, width = 12, height = 6, dpi = 300)

# ------------------------------------------------------------------------------
# 5. Ba??lant?? De??i??im Tablosu (Emerging vs. Vanishing Edges)
# ------------------------------------------------------------------------------
all_pairs <- expand.grid(From = node_names, To = node_names, stringsAsFactors = FALSE) %>%
  filter(From != To)

edges_combined <- all_pairs %>%
  left_join(edges_p1 %>% select(from, to, weight) %>% rename(TE_Historical = weight), by = c("From" = "from", "To" = "to")) %>%
  left_join(edges_p2 %>% select(from, to, weight) %>% rename(TE_Recent = weight), by = c("From" = "from", "To" = "to")) %>%
  replace_na(list(TE_Historical = 0, TE_Recent = 0)) %>%
  mutate(
    Delta_TE = round(TE_Recent - TE_Historical, 4),
    Connection_Status = case_when(
      TE_Historical == 0 & TE_Recent > 0 ~ "Emerging (Yeni Olu??an)",
      TE_Historical > 0 & TE_Recent == 0 ~ "Vanishing (Yok Olan)",
      TE_Historical > 0 & TE_Recent > 0 & Delta_TE > 0 ~ "Amplified (G????lenen)",
      TE_Historical > 0 & TE_Recent > 0 & Delta_TE < 0 ~ "Weakened (Zay??flayan)",
      TRUE ~ "No Edge"
    )
  ) %>%
  filter(Connection_Status != "No Edge") %>%
  arrange(desc(abs(Delta_TE)))

write_csv(edges_combined, "Table_Causal_Network_Structural_Shift.csv")
message(">>> ??a??sal a?? de??i??im tablosu kaydedildi: Table_Causal_Network_Structural_Shift.csv")