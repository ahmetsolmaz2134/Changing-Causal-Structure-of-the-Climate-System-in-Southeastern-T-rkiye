# Gerekli paketlerin y??klenmesi
if (!require("pacman")) install.packages("pacman")
pacman::p_load(nasapower, tidyverse, lubridate, SPEI)

# 1. 9 ??l ve Koordinatlar??n??n Tan??mlanmas??
cities <- tibble::tribble(
  ~city,        ~lat,     ~lon,
  "Adiyaman",   37.7644,  38.2786,
  "Batman",     37.8812,  41.1351,
  "Diyarbakir", 37.9144,  40.2306,
  "Gaziantep",  37.0662,  37.3833,
  "Kilis",      36.7184,  37.1212,
  "Mardin",     37.3130,  40.7436,
  "Siirt",      37.9326,  41.9403,
  "Sanliurfa",  37.1674,  38.7955,
  "Sirnak",     37.5164,  42.4610
)

# 2. ??ekilecek De??i??kenlerin Tan??mlanmas??
# T2M: S??cakl??k (??C)
# PRECTOTCORR: Ya?????? (mm/g??n)
# RH2M: Ba????l Nem (%)
# WS2M: R??zgar H??z?? (m/s)
# ALLSKY_SFC_SW_DWN: G??ne?? Radyasyonu (MJ/m??/g??n)
# EVPTRNS / EVPT: Evapotranspirasyon (mm/g??n)
params <- c("T2M", "PRECTOTCORR", "RH2M", "WS2M", "ALLSKY_SFC_SW_DWN", "EVPTRNS")

start_date <- "1990-01-01"
end_date   <- "2025-12-31"

# 3. NASA POWER API ??zerinden D??ng?? ile Verilerin ??ekilmesi
fetch_city_data <- function(city_name, lat, lon) {
  message(paste0("Veri indiriliyor: ", city_name, "..."))
  
  df <- get_power(
    community = "ag", # Agroclimatology
    pars = params,
    temporal_api = "daily",
    lonlat = c(lon, lat),
    dates = c(start_date, end_date)
  ) %>%
    mutate(city = city_name) %>%
    select(city, YYYYMMDD, YEAR, MM, DD, T2M, PRECTOTCORR, RH2M, WS2M, ALLSKY_SFC_SW_DWN, EVPTRNS)
  
  return(df)
}

# T??m ??ehirler i??in toplu indirme (purrr::pmap_dfr kullan??m??)
gap_climate_daily <- pmap_dfr(
  list(cities$city, cities$lat, cities$lon),
  fetch_city_data
)

# 4. FAO-56 Penman-Monteith ET0 Hesab?? (EVPTRNS eksik ise alternatif kontrol)
# E??er NASA POWER EVPTRNS verisinde eksiklik olursa T2M, RH2M, WS2M ve SW ile ET0 hesaplayal??m:
gap_climate_daily <- gap_climate_daily %>%
  rename(
    date = YYYYMMDD,
    year = YEAR,
    month = MM,
    day = DD,
    temp = T2M,
    precip = PRECTOTCORR,
    rh = RH2M,
    wind = WS2M,
    rad = ALLSKY_SFC_SW_DWN,
    et0_nasa = EVPTRNS
  )

# 5. Ayl??k Ortalamalara/Toplamlara D??n????t??rme (Transfer Entropisi i??in Ayl??k ??l??ek)
gap_climate_monthly <- gap_climate_daily %>%
  group_by(city, year, month) %>%
  summarise(
    temp_mean   = mean(temp, na.rm = TRUE),
    precip_tot  = sum(precip, na.rm = TRUE),
    rh_mean     = mean(rh, na.rm = TRUE),
    wind_mean   = mean(wind, na.rm = TRUE),
    rad_mean    = mean(rad, na.rm = TRUE),
    et0_tot     = sum(et0_nasa, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(date = ym(paste(year, month, sep = "-")))

# 6. Veriyi Kaydetme
write_csv(gap_climate_daily, "GAP_Climate_Daily_1990_2025.csv")
write_csv(gap_climate_monthly, "GAP_Climate_Monthly_1990_2025.csv")

message("T??m veriler ba??ar??yla indirildi ve kaydedildi!")