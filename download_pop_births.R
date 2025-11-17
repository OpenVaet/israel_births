# Create data directory if it doesn't exist
if (!dir.exists("data")) {
  dir.create("data", recursive = TRUE)
}

## 1. Download births file (fixed URL) -----------------------------

births_url  <- "https://www.cbs.gov.il/he/publications/doclib/2024/2.shnatonpopulation/st02_29.xlsx"
births_dest <- "data/births.xlsx"

download.file(
  url      = births_url,
  destfile = births_dest,
  mode     = "wb"
)

cat("Saved births file to", births_dest, "\n")

## 2. Download population files, 2013–2024 ------------------------

years <- 2013:2024

for (yr in years) {
    
  if (yr == 2014) {
    url  <- "https://www.cbs.gov.il/he/publications/DocLib/2014/ShnatonPopulation/pdf/st02_19x.pdf"
    ext  <- "pdf"
  } else if (yr == 2016) {
    url  <- "https://www.cbs.gov.il/he/publications/doclib/2016/2.shnatonpopulation/st02_19x.pdf"
    ext  <- "pdf"
  } else if (yr <= 2018) {
    base_url <- sprintf(
      "https://www.cbs.gov.il/he/publications/doclib/%d/2.%%20shnatonpopulation/st02_19x",
      yr
    )
    ext  <- "xls"
    url  <- paste0(base_url, ".", ext)
  }

  url  <- paste0(base_url, ".", ext)
  dest <- sprintf("data/population_%d.%s", yr, ext)
  
  res <- try(
    download.file(url, dest, mode = "wb"),
    silent = TRUE
  )
  
  if (!inherits(res, "try-error")) {
    cat("Downloaded population file for", yr, "from", url,
        "to", dest, "\n")
  } else {
    warning(sprintf("Could not download population file for year %d (tried %s)", yr, url))
  }
}
