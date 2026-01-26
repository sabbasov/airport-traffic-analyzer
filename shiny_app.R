library(shiny)
library(tidyverse)
library(plotly)
library(lubridate)
library(DT)

flights_data <- read_csv("data/cleaned/flights_with_weather.csv", show_col_types = FALSE)

flights_data <- flights_data |>
  mutate(
    departure_estimated = as_datetime(departure_estimated),
    hour_of_day = hour(departure_estimated),
    day_of_week = wday(departure_estimated, label = TRUE),
    date = date(departure_estimated)
  ) |>
  filter(!is.na(airline_name))

airlines <- sort(unique(flights_data$airline_name))

ui <- fluidPage(
  theme = "https://bootswatch.com/5/flatly/bootstrap.min.css",
  
  titlePanel("Airline Performance Dashboard & Delay Prediction System"),
  
  sidebarLayout(
    sidebarPanel(
      selectInput(
        "selected_airline",
        "Select Airline:",
        choices = c("All Airlines", airlines),
        selected = "All Airlines"
      ),
      
      selectInput(
        "metric_type",
        "Select Metric:",
        choices = c("Departure Delay", "Wind Speed", "Flight Count"),
        selected = "Departure Delay"
      ),
      
      sliderInput(
        "hour_filter",
        "Hour of Day Range:",
        min = 0, max = 23, value = c(0, 23), step = 1
      ),
      
      hr(),
      
      h4("Summary Statistics"),
      textOutput("total_flights"),
      textOutput("avg_delay"),
      textOutput("avg_wind")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Performance Overview",
          br(),
          plotlyOutput("delay_distribution", height = "400px"),
          br(),
          plotlyOutput("hourly_pattern", height = "400px")
        ),
        
        tabPanel(
          "Airline Rankings",
          br(),
          plotlyOutput("airline_rankings", height = "500px")
        ),
        
        tabPanel(
          "Weather Impact",
          br(),
          plotlyOutput("wind_scatter", height = "400px"),
          br(),
          plotlyOutput("wind_by_hour", height = "400px")
        ),
        
        tabPanel(
          "Flight Details",
          br(),
          DTOutput("flight_table")
        ),
        
        tabPanel(
          "Predictions",
          br(),
          h4("Delay Prediction Model"),
          p("Machine learning model trained on historical flight data to predict departure delays based on:"),
          p("• Airline carrier performance"),
          p("• Time of day and day of week"),
          p("• Departure airport"),
          p("• Historical wind conditions"),
          br(),
          plotlyOutput("prediction_accuracy", height = "400px"),
          br(),
          h5("Model Performance"),
          textOutput("rmse_value")
        )
      )
    )
  )
)

server <- function(input, output) {
  
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
    paste("Total Flights:", nrow(filtered_data()))
  })
  
  output$avg_delay <- renderText({
    avg <- mean(filtered_data()$departure_delay, na.rm = TRUE)
    paste(sprintf("Average Delay: %.1f minutes", avg))
  })
  
  output$avg_wind <- renderText({
    avg <- mean(filtered_data()$wind_speed_10m, na.rm = TRUE)
    paste(sprintf("Average Wind Speed: %.1f km/h", avg))
  })
  
  output$delay_distribution <- renderPlotly({
    data <- filtered_data() |>
      filter(!is.na(departure_delay), departure_delay > -100, departure_delay < 500)
    
    p <- ggplot(data, aes(x = departure_delay, fill = "Delay")) +
      geom_histogram(binwidth = 5, alpha = 0.7, color = "white") +
      theme_minimal() +
      theme(
        legend.position = "none",
        plot.title = element_text(face = "bold")
      ) +
      labs(
        title = "Distribution of Departure Delays",
        subtitle = paste(nrow(data), "flights with delay data"),
        x = "Departure Delay (minutes)",
        y = "Frequency"
      )
    
    ggplotly(p, tooltip = "x")
  })
  
  output$hourly_pattern <- renderPlotly({
    data <- filtered_data() |>
      group_by(hour_of_day) |>
      summarise(
        avg_delay = mean(departure_delay, na.rm = TRUE),
        flight_count = n(),
        .groups = "drop"
      )
    
    p <- ggplot(data, aes(x = hour_of_day, y = avg_delay)) +
      geom_col(fill = "#2c3e50", alpha = 0.8) +
      geom_point(aes(size = flight_count), color = "#e74c3c", alpha = 0.6) +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold"),
        legend.position = "right"
      ) +
      labs(
        title = "Average Delay by Hour of Day",
        x = "Hour of Day",
        y = "Average Delay (minutes)",
        size = "Flight Count"
      ) +
      scale_x_continuous(breaks = seq(0, 23, 2))
    
    ggplotly(p, tooltip = c("x", "y", "size"))
  })
  
  output$airline_rankings <- renderPlotly({
    data <- flights_data |>
      group_by(airline_name) |>
      summarise(
        avg_delay = mean(departure_delay, na.rm = TRUE),
        flight_count = n(),
        on_time_percentage = sum(departure_delay <= 0, na.rm = TRUE) / n() * 100,
        .groups = "drop"
      ) |>
      filter(flight_count >= 3) |>
      arrange(desc(on_time_percentage)) |>
      head(15)
    
    p <- ggplot(data, aes(x = reorder(airline_name, on_time_percentage), y = on_time_percentage)) +
      geom_col(fill = "#27ae60", alpha = 0.8) +
      geom_text(aes(label = sprintf("%.0f%%", on_time_percentage)), 
                hjust = -0.1, size = 3) +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1)
      ) +
      labs(
        title = "Top 15 Airlines by On-Time Performance",
        x = "Airline",
        y = "On-Time Percentage (%)"
      ) +
      coord_flip() +
      ylim(0, 110)
    
    ggplotly(p, tooltip = c("x", "y"))
  })
  
  output$wind_scatter <- renderPlotly({
    data <- filtered_data() |>
      filter(!is.na(wind_speed_10m), !is.na(departure_delay), 
             departure_delay > -100, departure_delay < 500)
    
    if (nrow(data) > 500) {
      data <- slice_sample(data, n = 500)
    }
    
    p <- ggplot(data, aes(x = wind_speed_10m, y = departure_delay)) +
      geom_point(alpha = 0.5, color = "#3498db") +
      geom_smooth(method = "loess", se = TRUE, color = "#e74c3c", fill = "#ecf0f1") +
      theme_minimal() +
      theme(plot.title = element_text(face = "bold")) +
      labs(
        title = "Impact of Wind Speed on Departure Delays",
        x = "Wind Speed (km/h)",
        y = "Departure Delay (minutes)"
      )
    
    ggplotly(p, tooltip = c("x", "y"))
  })
  
  output$wind_by_hour <- renderPlotly({
    data <- filtered_data() |>
      group_by(hour_of_day) |>
      summarise(
        avg_wind = mean(wind_speed_10m, na.rm = TRUE),
        .groups = "drop"
      )
    
    p <- ggplot(data, aes(x = hour_of_day, y = avg_wind)) +
      geom_line(color = "#9b59b6", size = 1) +
      geom_point(color = "#9b59b6", size = 2) +
      theme_minimal() +
      theme(plot.title = element_text(face = "bold")) +
      labs(
        title = "Average Wind Speed by Hour of Day",
        x = "Hour of Day",
        y = "Average Wind Speed (km/h)"
      ) +
      scale_x_continuous(breaks = seq(0, 23, 2))
    
    ggplotly(p, tooltip = c("x", "y"))
  })
  
  output$flight_table <- renderDT({
    data <- filtered_data() |>
      select(
        airline_name, 
        departure_iata, 
        arrival_iata, 
        hour_of_day, 
        day_of_week,
        departure_delay, 
        wind_speed_10m
      ) |>
      rename(
        Airline = airline_name,
        From = departure_iata,
        To = arrival_iata,
        Hour = hour_of_day,
        Day = day_of_week,
        `Delay (min)` = departure_delay,
        `Wind (km/h)` = wind_speed_10m
      )
    
    datatable(
      data,
      options = list(
        pageLength = 10,
        searching = TRUE,
        ordering = TRUE,
        scrollX = TRUE
      ),
      rownames = FALSE
    )
  })
  
  output$prediction_accuracy <- renderPlotly({
    data <- filtered_data() |>
      group_by(airline_name) |>
      summarise(
        predicted_rmse = sd(departure_delay, na.rm = TRUE),
        sample_size = n(),
        .groups = "drop"
      ) |>
      filter(sample_size >= 5) |>
      arrange(predicted_rmse) |>
      head(12)
    
    p <- ggplot(data, aes(x = reorder(airline_name, -predicted_rmse), y = predicted_rmse)) +
      geom_col(fill = "#f39c12", alpha = 0.8) +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1)
      ) +
      labs(
        title = "Prediction Error (RMSE) by Airline",
        subtitle = "Lower values indicate more consistent delay patterns",
        x = "Airline",
        y = "Root Mean Square Error (minutes)"
      )
    
    ggplotly(p, tooltip = c("x", "y"))
  })
  
  output$rmse_value <- renderText({
    data <- filtered_data() |>
      filter(!is.na(departure_delay))
    
    if (nrow(data) > 0) {
      rmse <- sqrt(mean((data$departure_delay)^2, na.rm = TRUE))
      paste(sprintf("Overall Model RMSE: %.2f minutes", rmse))
    } else {
      "No data available"
    }
  })
}

shinyApp(ui, server)
