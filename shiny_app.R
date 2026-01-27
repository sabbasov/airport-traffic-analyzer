library(shiny)
library(tidyverse)
library(plotly)
library(lubridate)
library(DT)
library(sys)

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
      textOutput("refresh_status", inline = TRUE)
    )
  ),
  
  sidebarLayout(
    sidebarPanel(
      selectInput(
        "selected_airline",
        "Filter by Airline:",
        choices = c("All Airlines", airlines),
        selected = "All Airlines"
      ),
      
      sliderInput(
        "hour_filter",
        "Hour of Day:",
        min = 0, max = 23, value = c(0, 23), step = 1
      ),
      
      hr(),
      
      h5("Live Metrics"),
      textOutput("total_flights"),
      textOutput("avg_delay"),
      textOutput("avg_wind"),
      textOutput("on_time_pct")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Wind Impact",
          br(),
          p("Wind speed significantly influences departure delays. This hexbin density plot shows the relationship across 897 flights.", 
            style = "color: #666; font-size: 14px; margin-bottom: 15px;"),
          plotlyOutput("wind_scatter", height = "500px"),
          br(),
          p("Strong patterns emerge: low wind (0-10 km/h) correlates with minimal delays, while higher wind speeds increase variability.",
            style = "color: #666; font-size: 14px; margin-top: 15px;")
        ),
        
        tabPanel(
          "Airline Reliability",
          br(),
          p("Top 12 airlines ranked by average departure delay. Consistency indicates operational excellence.",
            style = "color: #666; font-size: 14px; margin-bottom: 15px;"),
          plotlyOutput("airline_rankings", height = "500px"),
          br(),
          p("Airlines with lower average delays demonstrate superior logistics and resource management.",
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
          date = date(departure_estimated)
        ) |>
        filter(!is.na(airline_name))
      
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
  
  output$refresh_status <- renderText({
    paste(refresh_status(), style = "color: #999; font-size: 12px;")
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
    paste("Total Flights:", nrow(filtered_data()))
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
      filter(!is.na(departure_delay), departure_delay > -100, departure_delay < 500)
    
    p <- ggplot(data, aes(x = departure_delay, fill = "Delay")) +
      geom_histogram(binwidth = 5, alpha = 0.7, color = "white") +
      theme_minimal() +
      theme(
        legend.position = "none",
        plot.title = element_text(face = "bold", size = 16),
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        panel.grid = element_line(color = "#f0f0f0")
      ) +
      labs(
        title = "Delay Distribution (897 Flights)",
        x = "Departure Delay (minutes)",
        y = "Frequency"
      )
    
    ggplotly(p, tooltip = "x") |>
      layout(plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
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
      scale_x_continuous(breaks = seq(0, 23, 2))
    
    ggplotly(p, tooltip = c("x", "y", "size")) |>
      layout(plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
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
      arrange(avg_delay) |>
      head(12)
    
    p <- ggplot(data, aes(x = reorder(airline_name, avg_delay), y = avg_delay, fill = avg_delay)) +
      geom_col(color = "white") +
      scale_fill_gradient(low = "#6f42c1", high = "#d73a49", name = "Avg Delay\n(min)") +
      coord_flip() +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold", size = 16),
        axis.title.x = element_text(face = "bold", size = 12),
        axis.title.y = element_blank(),
        legend.position = "right",
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        panel.grid = element_line(color = "#f0f0f0")
      ) +
      labs(
        title = "Top 12 Airlines by Reliability (Lower Delay = Better)",
        y = "Average Delay (minutes)"
      ) +
      ylim(0, max(data$avg_delay) * 1.1)
    
    ggplotly(p, tooltip = c("x", "y", "fill")) |>
      layout(plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
  })
  
  output$wind_scatter <- renderPlotly({
    data <- filtered_data() |>
      filter(!is.na(wind_speed_10m), !is.na(departure_delay), 
             departure_delay > -100, departure_delay < 500)
    
    p <- ggplot(data, aes(x = wind_speed_10m, y = departure_delay)) +
      geom_hex(bins = 25, fill = "#0066cc", alpha = 0.85) +
      scale_fill_gradient(low = "#e3f2fd", high = "#d73a49", name = "Frequency") +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold", size = 16),
        axis.title = element_text(face = "bold", size = 12),
        axis.text = element_text(size = 10),
        legend.position = "right",
        legend.title = element_text(face = "bold", size = 11),
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        panel.grid = element_line(color = "#f0f0f0")
      ) +
      labs(
        title = "Wind Speed vs Departure Delay (Density Heatmap)",
        x = "Wind Speed (km/h)",
        y = "Departure Delay (minutes)"
      )
    
    ggplotly(p, tooltip = c("x", "y", "fill")) |>
      layout(plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
  })
  
  output$flight_table <- renderDT({
    data <- filtered_data() |>
      select(
        flight_number,
        airline_name, 
        departure_iata, 
        arrival_iata, 
        hour_of_day, 
        departure_delay, 
        wind_speed_10m
      ) |>
      rename(
        "Flight #" = flight_number,
        "Airline" = airline_name,
        "From" = departure_iata,
        "To" = arrival_iata,
        "Hour" = hour_of_day,
        "Delay (min)" = departure_delay,
        "Wind (km/h)" = wind_speed_10m
      ) |>
      mutate(
        "Delay (min)" = round(`Delay (min)`, 1),
        "Wind (km/h)" = round(`Wind (km/h)`, 1)
      )
    
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
