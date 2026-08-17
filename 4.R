all_cities <- unique(climate_variability$city)

# 9 ??lin Tamam?? ????in Otomatik D??ng??
walk(all_cities, ~generate_city_plot(.x, climate_variability))