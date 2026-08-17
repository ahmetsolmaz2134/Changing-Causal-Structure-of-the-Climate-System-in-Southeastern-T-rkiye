# 9 ??lin S??cakl??k Anomali Trendlerinin B??lgesel Matrisi
p_regional_temp <- ggplot(climate_variability %>% filter(variable == "temp_mean"), 
                          aes(x = date, y = standardized_anomaly)) +
  geom_col(aes(fill = standardized_anomaly > 0), position = "identity", width = 25, show.legend = FALSE) +
  geom_smooth(method = "loess", span = 0.2, color = "black", linewidth = 0.7, se = FALSE) +
  geom_hline(yintercept = 0, color = "grey20", linewidth = 0.4) +
  scale_fill_manual(values = c("TRUE" = "#d73027", "FALSE" = "#4575b4")) +
  facet_wrap(~city, ncol = 3) +
  scale_x_date(date_breaks = "10 years", date_labels = "%Y") +
  labs(
    title = "Southeastern T??rkiye: Regional Temperature Anomalies across 9 Provinces (1990???2025)",
    subtitle = "Standardized monthly temperature anomalies (Z-Score) with LOESS smooth trendlines",
    x = "Year",
    y = "Temperature Anomaly (Z-Score)"
  ) +
  theme_academic()

ggsave("Figure_Regional_9Provinces_Temperature.png", plot = p_regional_temp, 
       width = 12, height = 9, dpi = 300)