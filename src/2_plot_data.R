# VISUALIZE TRACKING DATA

library(tidyr)
library(dplyr)
library(RSQLite)
library(lubridate)
library(ggplot2)
library(forecast)


# LOAD FROM DATABASE ----
con <- dbConnect(dbDriver("SQLite"), dbname = "data/xiaomi.sqlite")

activity <-
  dbGetQuery(con,
             "SELECT timestamp AS timestamp, steps AS steps,
             heart_rate AS hr
             FROM mi_band_activity_sample")

dbDisconnect(con)


# PREPROCESS ----
# clean data fields
activity_clean <-
  activity %>%
  # timestamp to datetime
  mutate(datetime = as.POSIXct(timestamp, origin = "1970-01-01")) %>% 
  mutate(weekday = wday(datetime)) %>% 
  select(-timestamp) %>% 
  # define NA values
  mutate(steps = ifelse(steps <= 0, NA, steps)) %>% 
  mutate(hr = ifelse(hr <= 0 | hr == 255, NA, hr))


# DISTRIBUTIONS ----
# histogram of individual heart rate measurements
ggplot(data = activity_clean, aes(x = hr)) + 
  geom_histogram() +
  theme_bw()

# histogram of steps per day
activity_clean %>% 
  group_by(date = floor_date(datetime, unit = "day")) %>% 
  summarise(steps_sum = sum(steps, na.rm = T)) %>% 
  ungroup %>% 
  ggplot(data = ., aes(x = steps_sum)) + 
  geom_histogram() +
  theme_bw()


# TIME SERIES PER DAY ----
# aggregate time intervals
activity_agg <-
  activity_clean %>% 
  group_by(date = floor_date(datetime, unit = "day")) %>% 
  summarise(hr_0.25 = quantile(hr, .25, na.rm = T),
            steps_sum = sum(steps, na.rm = T)) %>% 
  ungroup %>% 
  mutate(steps_sum = ifelse(steps_sum == 0, NA, steps_sum))

# daily heart rate over time
activity_agg %>%
  gather(measurement, value, -date) %>% 
  ggplot(data = ., aes(x = date, y = value)) +
  geom_line() +
  facet_grid(measurement ~ ., scales = "free_y") +
  theme_bw()


# COMPARING WEEKDAYS ----
activity_agg %>%
  mutate(weekday = wday(date)) %>% 
  ggplot(data = ., aes(x = weekday, y = hr_0.25)) +
  geom_boxplot(aes(group = weekday)) +
  theme_bw()

activity_agg %>%
  mutate(weekday = wday(date)) %>% 
  ggplot(data = ., aes(x = weekday, y = steps_sum)) +
  geom_boxplot(aes(group = weekday)) +
  theme_bw()

# AUTOCORRELATION ----
ggPacf(activity_agg$hr_0.25)
ggPacf(activity_agg$steps_sum)


# SAVE DATA ----
save(activity_agg, file = "data/processed/activity_agg.Rdata")
