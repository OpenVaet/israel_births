# Packages ---------------------------------------------------------------
library(readr)
library(dplyr)
library(ggplot2)

# 1. Read female population by age (2018-2023) --------------------------
pop_raw <- read_delim(
  "data/population_2018_2023.csv",
  delim = ";",
  trim_ws = TRUE,
  locale = locale(decimal_mark = ",", grouping_mark = " ")
)

pop_women_15_44 <- pop_raw %>%
  transmute(
    Population = `Population (Females)`,
    Year = as.integer(Year),
    women_15_44_thousands = `15-19` + `20-24` + `25-29` + `30-34` + `35-44`,
    women_15_44 = women_15_44_thousands * 1000
  )

# 2. Read births (2018-2023) -------------------------------------------
births_raw <- read_delim(
  "data/births_2018_2023.csv",
  delim = ";",
  trim_ws = TRUE,
  col_types = cols(.default = "c")
)

births <- births_raw %>%
  transmute(
    Population,
    Year = as.integer(Year),
    live_births = parse_number(`Live births`, locale = locale(grouping_mark = " "))
  )

# 3. Merge and compute rates -------------------------------------------
df_rates <- births %>%
  inner_join(pop_women_15_44, by = c("Population", "Year")) %>%
  mutate(
    births_per_1000_women_15_44 = live_births / women_15_44 * 1000
  )

# 4. Plot: larger fonts, thicker lines, value labels --------------------
ggplot(df_rates, aes(x = Year, y = births_per_1000_women_15_44, colour = Population)) +
  geom_line(size = 1.8) +         # thicker lines
  geom_point(size = 3.5) +        # bigger points
  geom_text(
    aes(label = round(births_per_1000_women_15_44, 1)),
    vjust = -0.8,
    size = 5,
    show.legend = FALSE
  ) +
  scale_x_continuous(breaks = 2018:2023) +
  labs(
    x = "Year",
    y = "Live births per 1,000 women aged 15-44",
    colour = "Population",
    title = "Live births per 1,000 women aged 15-44 in Israel",
    subtitle = "By population group, 2018-2023"
  ) +
  theme_minimal(base_size = 16) +  # overall larger base font
  theme(
    axis.title = element_text(size = 18),
    axis.text  = element_text(size = 14),
    legend.title = element_text(size = 16),
    legend.text  = element_text(size = 14),
    plot.title = element_text(size = 20, face = "bold"),
    plot.subtitle = element_text(size = 16)
  )
