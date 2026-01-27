library(shiny)
library(tidyverse)
library(plotly)
library(lubridate)
library(DT)
library(sys)

# Load the trained ML model
trained_model <- readRDS("model_training.rds")

flights_data <- read_csv("data/cleaned/flights_with_weather.csv", show_col_types = FALSE)

flights_data <- flights_data |>
  mutate(
    departure_estimated = as_datetime(departure_estimated),
    hour_of_day = hour(departure_estimated),
    day_of_week = wday(departure_estimated, label = TRUE),
    date = date(departure_estimated),
    # Cap extreme delay outliers at 300 minutes for data validation
    departure_delay_capped = pmin(departure_delay, 300),
    # Ensure departure_delay is numeric and handle outliers
    departure_delay = as.numeric(departure_delay),
    departure_delay = case_when(
      departure_delay > 300 ~ NA_real_,  # Flag extreme outliers as missing
      TRUE ~ departure_delay
    )
  ) |>
  filter(!is.na(airline_name), !is.na(flight_number), flight_number != "")

airlines <- sort(unique(flights_data$airline_name))

ui <- fluidPage(
  theme = "https://bootswatch.com/5/flatly/bootstrap.min.css",
  
  tags$head(
    tags$style(HTML("
      .navbar-custom {
        background-color: #ffffff;
        border-bottom: 2px solid #0066cc;
        padding: 10px 20px;
        display: flex;
        justify-content: space-between;x
        align-items: center;
        margin-bottom: 20px;
      }
      .navbar-title {
        font-size: 24px;
        font-weight: bold;
        color: #001f3f;
        letter-spacing: -0.5px;
      }
      .refresh-btn {
        background-color: #0066cc;
        color: white;
        border: none;
        padding: 10px 20px;
        border-radius: 6px;
        font-weight: bold;
        cursor: pointer;
        transition: all 0.3s ease;
        font-size: 14px;
      }
      .refresh-btn:hover {
        background-color: #0052a3;
        box-shadow: 0 4px 12px rgba(0, 102, 204, 0.3);
      }
      .refresh-btn:active {
        transform: scale(0.98);
      }
      .status-text {
        font-size: 12px;
        color: #666;
        margin-top: 5px;
      }
      .plotly {
        background-color: transparent !important;
      }
      svg {
        background-color: transparent !important;
      }
    "))
  ),
  
  div(class = "navbar-custom",
    div(class = "navbar-title", "✈ Airline Performance Monitor"),
    div(
      actionButton("refresh_btn", "System Refresh", class = "refresh-btn"),
      br(),
      uiOutput("refresh_status")
    )
  ),
  
  sidebarLayout(
    sidebarPanel(
      h5("Live Metrics"),
      textOutput("total_flights"),
      textOutput("avg_delay"),
      textOutput("avg_wind"),
      textOutput("on_time_pct")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Airline Comparison",
          br(),
          p("Ranked by average delay. Choose airlines with consistently low delays to avoid operational disruptions.", 
            style = "color: #666; font-size: 14px; margin-bottom: 15px;"),
          plotlyOutput("airline_delay_comparison", height = "550px"),
          br(),
          p("Red indicators show carriers with significant delays; use this ranking for booking decisions.",
            style = "color: #666; font-size: 14px; margin-top: 15px;")
        ),
        
        tabPanel(
          "Wind Sensitivity",
          br(),
          p("Scatter plot with trend line showing the exact correlation between wind speed and delays. Identifies the critical wind speed threshold where delays spike.",
            style = "color: #666; font-size: 14px; margin-bottom: 15px;"),
          plotlyOutput("wind_sensitivity_index", height = "550px"),
          br(),
          p("If wind exceeds the trend line spike point, expect potential delays. Plan buffer time accordingly.",
            style = "color: #666; font-size: 14px; margin-top: 15px;")
        ),
        
        tabPanel(
          "Temporal Risk",
          br(),
          p("Heatmap identifying danger zones for delays by hour of day and day of week. Red zones indicate highest risk times.",
            style = "color: #666; font-size: 14px; margin-bottom: 15px;"),
          plotlyOutput("temporal_risk_heatmap", height = "550px"),
          br(),
          p("Book flights during green zones (low delay hours) on preferred days. Avoid peak hours and high-risk combinations.",
            style = "color: #666; font-size: 14px; margin-top: 15px;")
        ),
        
        tabPanel(
          "Delay Patterns",
          br(),
          plotlyOutput("delay_distribution", height = "400px"),
          br(),
          plotlyOutput("hourly_pattern", height = "400px")
        ),
        
        tabPanel(
          "Flight Details",
          br(),
          fluidRow(
            column(6,
              selectInput(
                "selected_airline",
                "Filter by Airline:",
                choices = c("All Airlines", airlines),
                selected = "All Airlines"
              )
            ),
            column(6,
              sliderInput(
                "hour_filter",
                "Hour of Day:",
                min = 0, max = 23, value = c(0, 23), step = 1
              )
            )
          ),
          br(),
          DTOutput("flight_table")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  
  refresh_status <- reactiveVal("Last updated: Now")
  
  observeEvent(input$refresh_btn, {
    showModal(modalDialog(
      title = "System Refresh",
      "Fetching latest flight data...",
      footer = NULL,
      easyClose = FALSE
    ))
    
    tryCatch({
      system("./setup.sh data", wait = TRUE)
      flights_data <<- read_csv("data/cleaned/flights_with_weather.csv", show_col_types = FALSE) |>
        mutate(
          departure_estimated = as_datetime(departure_estimated),
          hour_of_day = hour(departure_estimated),
          day_of_week = wday(departure_estimated, label = TRUE),
          date = date(departure_estimated),
          departure_delay = as.numeric(departure_delay),
          departure_delay = case_when(
            departure_delay > 300 ~ NA_real_,
            TRUE ~ departure_delay
          )
        ) |>
        filter(!is.na(airline_name), !is.na(flight_number), flight_number != "")
      
      removeModal()
      refresh_status(paste("Last updated:", format(Sys.time(), "%H:%M:%S")))
      session$reload()
    }, error = function(e) {
      removeModal()
      showModal(modalDialog(
        title = "Error",
        paste("Refresh failed:", conditionMessage(e)),
        easyClose = TRUE
      ))
    })
  })
  
  output$refresh_status <- renderUI({
    HTML(paste0("<div style='color: #999; font-size: 12px;'>", refresh_status(), "</div>"))
  })
  
  filtered_data <- reactive({
    data <- flights_data
    
    if (input$selected_airline != "All Airlines") {
      data <- data |> filter(airline_name == input$selected_airline)
    }
    
    data <- data |>
      filter(
        hour_of_day >= input$hour_filter[1],
        hour_of_day <= input$hour_filter[2]
      )
    
    data
  })
  
  output$total_flights <- renderText({
    # Count total flights from full dataset, not filtered
    total <- nrow(flights_data)
    paste("Total Flights:", total)
  })
  
  output$avg_delay <- renderText({
    avg <- mean(filtered_data()$departure_delay, na.rm = TRUE)
    paste(sprintf("Average Delay: %.1f min", round(avg, 1)))
  })
  
  output$avg_wind <- renderText({
    avg <- mean(filtered_data()$wind_speed_10m, na.rm = TRUE)
    paste(sprintf("Wind Speed: %.1f km/h", round(avg, 1)))
  })
  
  output$on_time_pct <- renderText({
    pct <- sum(filtered_data()$departure_delay <= 0, na.rm = TRUE) / nrow(filtered_data()) * 100
    paste(sprintf("On-Time: %.0f%%", pct))
  })
  
  output$delay_distribution <- renderPlotly({
    data <- filtered_data() |>
      filter(!is.na(departure_delay), departure_delay > -10, departure_delay <= 40)
    
    p <- ggplot(data, aes(x = departure_delay, fill = "Delay")) +
      geom_histogram(binwidth = 2, alpha = 0.7, color = "white") +
      theme_minimal() +
      theme(
        legend.position = "none",
        plot.title = element_text(face = "bold", size = 16),
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        panel.grid = element_line(color = "#f0f0f0")
      ) +
      labs(
        title = "Delay Distribution",
        x = "Departure Delay (minutes)",
        y = "Frequency"
      )
    
    ggplotly(p, tooltip = "x") |>
      layout(plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
  })
  
  output$hourly_pattern <- renderPlotly({
    data <- filtered_data() |>
      filter(!is.na(departure_delay)) |>
      group_by(hour_of_day) |>
      summarise(
        avg_delay = mean(departure_delay, na.rm = TRUE),
        flight_count = n(),
        .groups = "drop"
      ) |>
      filter(flight_count > 0)
    
    # Find first and last hours with data
    min_hour <- min(data$hour_of_day)
    max_hour <- max(data$hour_of_day)
    
    p <- ggplot(data, aes(x = hour_of_day, y = avg_delay)) +
      geom_col(fill = "#0066cc", alpha = 0.7) +
      geom_point(aes(size = flight_count), color = "#d73a49", alpha = 0.6) +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold", size = 16),
        legend.position = "right",
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        panel.grid = element_line(color = "#f0f0f0")
      ) +
      labs(
        title = "Average Delay by Hour",
        x = "Hour of Day",
        y = "Average Delay (minutes)",
        size = "Flight Count"
      ) +
      scale_x_continuous(breaks = seq(floor(min_hour), ceiling(max_hour), 1), limits = c(min_hour - 0.5, max_hour + 0.5))
    
    ggplotly(p, tooltip = c("x", "y", "size")) |>
      layout(plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
  })
  
  output$airline_delay_comparison <- renderPlotly({
    data <- flights_data |>
      filter(!is.na(airline_name), !is.na(departure_delay)) |>
      group_by(airline_name) |>
      summarise(
        avg_delay = mean(departure_delay, na.rm = TRUE),
        flight_count = n(),
        .groups = "drop"
      ) |>
      filter(flight_count >= 3) |>
      # Group airlines with <5 min avg delay into "Other Carriers"
      mutate(
        display_airline = case_when(
          avg_delay < 5 ~ "Other Carriers (Reliable)",
          TRUE ~ airline_name
        )
      ) |>
      group_by(display_airline) |>
      summarise(
        avg_delay = mean(avg_delay, na.rm = TRUE),
        flight_count = sum(flight_count, na.rm = TRUE),
        .groups = "drop"
      ) |>
      arrange(desc(avg_delay))
    
    p <- ggplot(data, aes(x = reorder(display_airline, -avg_delay), y = avg_delay, fill = avg_delay)) +
      geom_col(color = "white", size = 0.5) +
      scale_fill_gradient(low = "#27ae60", high = "#e74c3c", name = "Avg Delay\n(min)") +
      coord_flip() +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold", size = 16, color = "#001f3f"),
        axis.title.x = element_text(face = "bold", size = 12),
        axis.title.y = element_blank(),
        axis.text = element_text(size = 10),
        legend.position = "right",
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        panel.grid.major.x = element_line(color = "#f0f0f0", size = 0.3)
      ) +
      labs(
        title = "Airlines Ranked by Delay",
        subtitle = "Airlines with <5 min avg delay grouped as 'Other Carriers'",
        x = "Average Delay (minutes)"
      )
    
    ggplotly(p, tooltip = c("x", "y")) |>
      layout(plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
  })
  
  output$wind_sensitivity_index <- renderPlotly({
    data <- flights_data |>
      filter(!is.na(wind_speed_10m), !is.na(departure_delay),
             departure_delay > -50, departure_delay < 150) |>
      # Aggregate wind speeds into 0.5 km/h increments
      mutate(
        wind_bucket = round(wind_speed_10m * 2) / 2  # Round to nearest 0.5
      ) |>
      group_by(wind_bucket) |>
      summarise(
        avg_delay = mean(departure_delay, na.rm = TRUE),
        flight_count = n(),
        .groups = "drop"
      ) |>
      filter(flight_count >= 3)  # Only keep buckets with sufficient data
    
    p <- ggplot(data, aes(x = wind_bucket, y = avg_delay)) +
      geom_point(aes(size = flight_count), color = "#0066cc", alpha = 0.6) +
      geom_line(color = "#d73a49", size = 1.2) +
      geom_smooth(method = "loess", color = "#6f42c1", size = 1.2, 
                  fill = "#e3f2fd", alpha = 0.2, se = TRUE) +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold", size = 16, color = "#001f3f"),
        axis.title = element_text(face = "bold", size = 12),
        axis.text = element_text(size = 10),
        legend.position = "right",
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = "#f0f0f0", size = 0.3)
      ) +
      labs(
        title = "Wind Speed vs Delay Correlation (0.5 km/h Buckets)",
        subtitle = "Red line = observed trend, Purple curve = smoothed pattern. Clear threshold visible where delays spike.",
        x = "Wind Speed (km/h, aggregated 0.5 increments)",
        y = "Average Departure Delay (minutes)",
        size = "Flight Count"
      )
    
    ggplotly(p, tooltip = c("x", "y", "size")) |>
      layout(plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
  })
  
  output$temporal_risk_heatmap <- renderPlotly({
    data <- flights_data |>
      filter(!is.na(departure_delay)) |>
      group_by(hour_of_day, day_of_week) |>
      summarise(
        avg_delay = mean(departure_delay, na.rm = TRUE),
        flight_count = n(),
        .groups = "drop"
      )
    
    p <- ggplot(data, aes(x = hour_of_day, y = day_of_week, fill = avg_delay)) +
      geom_tile(color = "white", size = 0.5) +
      scale_fill_gradient2(low = "#27ae60", mid = "#f39c12", high = "#e74c3c", 
                           midpoint = 12, name = "Avg Delay\n(min)",
                           na.value = "#cccccc",
                           limits = c(-10, 30)) +
      scale_x_continuous(breaks = seq(0, 23, 2)) +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold", size = 16, color = "#001f3f"),
        axis.title = element_text(face = "bold", size = 12),
        axis.text = element_text(size = 10),
        legend.position = "right",
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA)
      ) +
      labs(
        title = "Temporal Risk Heatmap: Danger Zones by Hour & Day",
        subtitle = "Green = safe booking times, Red = high delay risk",
        x = "Hour of Day",
        y = "Day of Week"
      )
    
    ggplotly(p, tooltip = c("x", "y", "fill")) |>
      layout(plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
  })
  
  output$flight_table <- renderDT({
    # Filter to only yesterday and today
    today <- Sys.Date()
    yesterday <- today - 1
    
    data <- filtered_data() |>
      filter(!is.na(flight_number), flight_number != "", !is.na(airline_name)) |>
      filter(date >= yesterday, date <= today) |>
      select(
        flight_number,
        airline_name, 
        departure_estimated,
        departure_iata, 
        arrival_iata,
        wind_speed_10m,
        hour_of_day, 
        day_of_week
      )
    
    # Generate predictions if we have data
    if (nrow(data) > 0) {
      # Prepare data for prediction (match model features from training)
      # Model was trained with: airline_name, departure_iata, arrival_iata, hour_of_day, day_of_week (numeric), wind_speed_10m
      data_for_pred <- data |>
        mutate(
          day_of_week = as.numeric(day_of_week)  # Convert factor to numeric
        ) |>
        select(airline_name, departure_iata, arrival_iata, hour_of_day, day_of_week, wind_speed_10m)
      
      # Make predictions
      tryCatch({
        predicted_delays <- predict(trained_model, data_for_pred)
        data <- data |>
          mutate(predicted_delay = as.numeric(predicted_delays))
      }, error = function(e) {
        # If prediction fails, log and use NA
        message("Prediction error: ", conditionMessage(e))
        data <<- data |>
          mutate(predicted_delay = NA_real_)
      })
    } else {
      data <- data |>
        mutate(predicted_delay = NA_real_)
    }
    
    data <- data |>
      select(
        flight_number,
        airline_name,
        departure_estimated,
        departure_iata,
        arrival_iata,
        predicted_delay,
        wind_speed_10m
      ) |>
      rename(
        "Flight #" = flight_number,
        "Airline" = airline_name,
        "Departure Time" = departure_estimated,
        "From" = departure_iata,
        "To" = arrival_iata,
        "Predicted Delay (min)" = predicted_delay,
        "Wind (km/h)" = wind_speed_10m
      ) |>
      mutate(
        "Departure Time" = format(`Departure Time`, "%Y-%m-%d %H:%M"),
        "Predicted Delay (min)" = round(`Predicted Delay (min)`, 1),
        "Wind (km/h)" = round(`Wind (km/h)`, 1)
      ) |>
      arrange(desc(`Departure Time`))
    
    datatable(
      data,
      options = list(
        pageLength = 15,
        searching = TRUE,
        ordering = TRUE,
        scrollX = TRUE,
        dom = 'lfrtip'
      ),
      rownames = FALSE,
      class = 'stripe hover'
    )
  })
}

shinyApp(ui, server)
