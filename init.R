# Install R packages for Heroku
packages <- c(
  'tidyverse',
  'tidymodels',
  'vip',
  'shiny',
  'plotly',
  'lubridate',
  'DT',
  'ranger',
  'shinyjs'
)

for (pkg in packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, repos = 'https://cran.r-project.org/')
  }
}
