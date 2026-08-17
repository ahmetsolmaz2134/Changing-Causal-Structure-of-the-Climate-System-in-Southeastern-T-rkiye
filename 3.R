# Akademik Grafik Temas?? (Nature / Elsevier Standartlar??)
theme_academic <- function() {
  theme_classic(base_size = 11, base_family = "sans") +
    theme(
      plot.title        = element_text(face = "bold", size = 12, hjust = 0),
      plot.subtitle     = element_text(size = 9, color = "grey30"),
      axis.title        = element_text(face = "bold", size = 10),
      axis.text         = element_text(color = "black", size = 9),
      panel.grid.major.y = element_line(color = "grey90", linewidth = 0.3),
      legend.position   = "bottom",
      legend.title      = element_text(face = "bold", size = 9),
      strip.background   = element_rect(fill = "grey95", color = "black", linewidth = 0.5),
      strip.text        = element_text(face = "bold", size = 10)
    )
}

# ??ehir Bazl?? Grafik ??retici Fonksiyon
generate_city_plot <- function(city_name, df_data) {
  
  df_city <- df_data %>% filter(city == city_name)
  
  # Panel A: Ayl??k Seri & 12-Ayl??k Hareketli Ortalama (S??cakl??k ve Ya??????)
  p1 <- ggplot(df_city %>% filter(variable %in% c("temp_mean", "precip_tot")), 
               aes(x = date)) +
    geom_line(aes(y = value), color = "grey60", alpha = 0.6, linewidth = 0.4) +
    geom_line(aes(y = roll_mean_12, color = var_label), linewidth = 0.9, na.rm = TRUE) +
    facet_wrap(~var_label, scales = "free_y", ncol = 1) +
    scale_color_manual(values = c("Mean Temperature (??C)" = "#d95f02", 
                                  "Total Precipitation (mm)" = "#1b9e77")) +
    scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    labs(
      title = paste0("A) Monthly Climate Series & 12-Month Moving Average (", city_name, ": 1990???2025)"),
      subtitle = "Grey line: Monthly raw values | Colored line: 12-month centered moving average",
      x = "Year", y = "Value"
    ) +
    theme_academic() +
    theme(legend.position = "none")
  
  # Panel B: Standartla??t??r??lm???? Anomaliler (Z-Score)
  p2 <- ggplot(df_city %>% filter(variable %in% c("temp_mean", "precip_tot")), 
               aes(x = date, y = standardized_anomaly)) +
    geom_col(aes(fill = standardized_anomaly > 0), 
             position = "identity", 
             width = 25, 
             show.legend = FALSE) +
    geom_hline(yintercept = c(-1.5, 1.5), linetype = "dashed", color = "black", linewidth = 0.4) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    scale_fill_manual(values = c("TRUE" = "#d73027", "FALSE" = "#4575b4")) +
    facet_wrap(~var_label, scales = "free_y", ncol = 1) +
    scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    labs(
      title = "B) Standardized Monthly Climate Anomalies (Z-Score)",
      subtitle = "Dashed lines indicate extreme thresholds (??1.5 SD)",
      x = "Year", y = "Standardized Anomaly (SD)"
    ) +
    theme_academic()
  
  # Panellerin Birle??tirilmesi
  final_plot <- p1 / p2 + plot_layout(heights = c(1, 1))
  
  # Dosyaya Kaydetme
  file_name <- paste0("Figure_Climate_Variability_", city_name, ".png")
  ggsave(file_name, plot = final_plot, width = 10, height = 9, dpi = 300)
  
  message(paste0("Grafik olu??turuldu: ", file_name))
}