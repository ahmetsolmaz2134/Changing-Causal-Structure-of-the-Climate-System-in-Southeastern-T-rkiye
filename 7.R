# ------------------------------------------------------------------------------
# 1. Package Installation and Setup
# ------------------------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, ggraph, igraph, viridis)

# Read Granger results if not already loaded
if (!exists("granger_physical_results")) {
  granger_physical_results <- read_csv("Table_Granger_Physical_9Provinces.csv")
}

# ------------------------------------------------------------------------------
# FIGURE 1: Granger F-Statistic Heatmap (English)
# ------------------------------------------------------------------------------
heatmap_data <- granger_physical_results %>%
  mutate(
    Pair = paste(Cause, "->", Effect),
    Significance = ifelse(p_value < 0.05, "Significant (p < 0.05)", "Non-significant (p >= 0.05)")
  )

p_heatmap <- ggplot(heatmap_data, aes(x = City, y = Pair, fill = F_Stat)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.2f\n(%s)", F_Stat, ifelse(p_value < 0.05, "*", "ns"))), 
            color = "black", size = 3.2, fontface = "bold") +
  scale_fill_viridis_c(option = "magma", direction = -1, name = "F-Statistic") +
  theme_minimal(base_size = 12) +
  labs(
    title = "Physical Granger Causality Across GAP Region Provinces",
    subtitle = "* Indicates statistical significance at 5% level (p < 0.05); 'ns' denotes non-significance.",
    x = "Province / City",
    y = "Physical Causality Pair (Cause -> Effect)"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, face = "bold"),
    axis.text.y = element_text(face = "bold"),
    panel.grid = element_blank(),
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "right"
  )

print(p_heatmap)
ggsave("Figure_Granger_Heatmap_EN.png", p_heatmap, width = 10, height = 6, dpi = 300)

# ------------------------------------------------------------------------------
# FIGURE 2: Directed Granger Causality Network Diagram (English)
# ------------------------------------------------------------------------------
# Fixing select conflict explicitly using dplyr::
sig_edges <- granger_physical_results %>%
  dplyr::filter(p_value < 0.05) %>%
  dplyr::select(Cause, Effect, F_Stat, City) %>%
  dplyr::rename(From = Cause, To = Effect, Weight = F_Stat)

graph_obj <- graph_from_data_frame(sig_edges, directed = TRUE)

p_network <- ggraph(graph_obj, layout = "circle") +
  geom_edge_link(aes(width = Weight, color = Weight), 
                 arrow = arrow(length = unit(4, 'mm')), 
                 end_cap = circle(6, 'mm'), 
                 alpha = 0.8) +
  geom_node_point(size = 8, color = "#1f77b4") +
  geom_node_text(aes(label = name), repel = TRUE, fontface = "bold", size = 4.5) +
  scale_edge_width(range = c(0.8, 2.5), name = "F-Stat Strength") +
  scale_edge_color_viridis(option = "viridis", name = "F-Statistic") +
  theme_void() +
  labs(
    title = "Causality Network of Significant Interactions (p < 0.05)",
    subtitle = "Arrows indicate direction of causality; line thickness scaled by F-statistic magnitude."
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5),
    legend.position = "bottom"
  )

print(p_network)
ggsave("Figure_Granger_Network_EN.png", p_network, width = 8, height = 8, dpi = 300)

# ------------------------------------------------------------------------------
# FIGURE 3: Province-wise F-Statistic Comparison Bar Chart (English)
# ------------------------------------------------------------------------------
p_bars <- ggplot(granger_physical_results, 
                 aes(x = reorder(paste(Cause, "->", Effect), F_Stat), 
                     y = F_Stat, 
                     fill = Is_Significant)) +
  geom_col(width = 0.7) +
  coord_flip() +
  facet_wrap(~ City, scales = "free_y", ncol = 3) +
  scale_fill_manual(values = c("Yes" = "#2b5c8f", "No" = "#d95f02"), 
                    name = "Significant (p < 0.05)?") +
  theme_bw(base_size = 11) +
  labs(
    title = "Granger Causality F-Statistics by Province",
    x = "Causal Interaction",
    y = "F-Statistic"
  ) +
  theme(
    strip.background = element_rect(fill = "grey90", color = NA),
    strip.text = element_text(face = "bold"),
    legend.position = "bottom",
    plot.title = element_text(face = "bold", size = 13)
  )

print(p_bars)
ggsave("Figure_Granger_Provinces_Bar_EN.png", p_bars, width = 12, height = 9, dpi = 300)