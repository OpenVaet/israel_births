# Packages ---------------------------------------------------------------
library(readr)
library(dplyr)
library(ggplot2)

# 1. Read female population by age (2012-2023) --------------------------
pop_raw <- read_delim(
  "data/population_2012_2023.csv",
  delim = ";",
  trim_ws = TRUE,
  locale = locale(decimal_mark = ",", grouping_mark = " ")
)
print(pop_raw)

pop_women_15_44 <- pop_raw %>%
  transmute(
    Population = Population,  # if needed: gsub(" FEMALES$", "", Population)
    Year = as.integer(Year),
    women_15_44_thousands = `15-19` + `20-24` + `25-29` + `30-34` + `35-44`,
    women_15_44 = women_15_44_thousands * 1000
  )
print(pop_women_15_44)

# 2. Read births (2012-2023) -------------------------------------------
births_raw <- read_delim(
  "data/births_2012_2023.csv",
  delim = ";",
  trim_ws = TRUE,
  col_types = cols(.default = "c")
)
print(births_raw)

births <- births_raw %>%
  transmute(
    Population,
    Year = as.integer(Year),
    live_births = parse_number(`Live births`, locale = locale(grouping_mark = " "))
  )
print(births, n = 50)

# 3. Merge and compute rates -------------------------------------------
df_rates <- births %>%
  inner_join(pop_women_15_44, by = c("Population", "Year")) %>%
  mutate(
    births_per_1000_women_15_44 = live_births / women_15_44 * 1000
  )
print(df_rates, n = 50)

# 3bis. Build linear trend (fit 2013-2019, project 2013-2023) ----------
# Estimate slope & intercept for each population using only 2013-2019
models <- df_rates %>%
  filter(Year >= 2013, Year <= 2019) %>%
  group_by(Population) %>%
  summarise(
    intercept = coef(lm(births_per_1000_women_15_44 ~ Year))[1],
    slope     = coef(lm(births_per_1000_women_15_44 ~ Year))[2],
    .groups   = "drop"
  )

# Create predicted trend values 2013-2023 for each population
trend_lines <- expand.grid(
  Population = unique(df_rates$Population),
  Year       = 2013:2023,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
) %>%
  as_tibble() %>%
  left_join(models, by = "Population") %>%
  mutate(
    births_trend = intercept + slope * Year,
    segment = ifelse(Year <= 2019, "fitted", "projected")
  )

# 3ter. Build labels with deviation from trend (for 2020-2023) ---------
df_plot <- df_rates %>%
  left_join(
    trend_lines %>% select(Population, Year, births_trend),
    by = c("Population", "Year")
  ) %>%
  mutate(
    dev_pct = if_else(
      Year >= 2020 & !is.na(births_trend),
      100 * (births_per_1000_women_15_44 - births_trend) / births_trend,
      NA_real_
    ),
    label = case_when(
      Year >= 2020 & !is.na(dev_pct) ~ paste0(
        round(births_per_1000_women_15_44, 1),
        " (",
        if_else(dev_pct >= 0, "+", "-"),
        abs(round(dev_pct, 1)),
        "%)"
      ),
      TRUE ~ as.character(round(births_per_1000_women_15_44, 1))
    )
  )

# 4. Plot: larger fonts, thicker lines, value labels + trend -----------
ggplot(df_plot, aes(x = Year, y = births_per_1000_women_15_44, colour = Population)) +
  # actual data
  geom_line(size = 1.8) +
  geom_point(size = 3.5) +
  # labels: nudged up and to the right
  geom_text(
    aes(label = label),
    nudge_x = 0.15,   # move slightly to the right
    nudge_y = 0.4,    # move slightly upwards
    hjust   = 0,      # left-align text relative to its x position
    size    = 5,
    show.legend = FALSE
  ) +
  # Fitted trend (2013-2019) - solid
  geom_line(
    data = subset(trend_lines, segment == "fitted"),
    aes(y = births_trend),
    size = 1.2,
    linetype = "solid",
    show.legend = FALSE
  ) +
  # Projected trend (2020-2023) - dashed
  geom_line(
    data = subset(trend_lines, segment == "projected"),
    aes(y = births_trend),
    size = 1.2,
    linetype = "dashed",
    show.legend = FALSE
  ) +
  # extend x-axis to the right so labels at 2023 + nudge are visible
  scale_x_continuous(
    breaks = 2012:2023,
    limits = c(2012, 2023.6)
  ) +
  labs(
    x = "Year",
    y = "Live births per 1,000 women aged 15-44",
    colour = "Population",
    title = "Live births per 1,000 women aged 15-44 in Israel",
    subtitle = "By population group, 2012-2023\nTrend fitted on 2013-2019"
  ) +
  theme_minimal(base_size = 16) +
  theme(
    axis.title = element_text(size = 18),
    axis.text  = element_text(size = 14),
    legend.title = element_text(size = 16),
    legend.text  = element_text(size = 14),
    plot.title = element_text(size = 20, face = "bold"),
    plot.subtitle = element_text(size = 16)
  )
