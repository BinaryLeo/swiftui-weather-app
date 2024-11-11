


# Weather App

A modern, SwiftUI-based weather application that provides detailed weather forecasts using the MET Norway Weather API.

## Features

- 🔍 Location search functionality
- 🌡️ Current weather conditions
- 📅 5-day weather forecast
- 🎨 Beautiful gradient UI
- 📱 Responsive design
- 🌍 International location support

## Screenshots

![Screenshot 2024-11-11 at 02 09 00 (2)](https://github.com/user-attachments/assets/f5002c30-aa0c-4792-8e43-47c9aeea8928)

## Requirements

- iOS 14.0+
- Xcode 13.0+
- Swift 5.5+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/weather-app.git
```

2. Create a `Config.swift` file in the project root and add your API key:
```swift
enum Config {
    static let apiKey = "YOUR_API_KEY_HERE"
}
```

3. Open the project in Xcode:
```bash
cd weather-app
open WeatherApp.xcodeproj
```

## Architecture

The app follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: Data structures for weather and location information
- **Views**: SwiftUI views for UI components
- **ViewModel**: `WeatherViewModel` handling business logic and data processing

## Key Components

### WeatherViewModel
Manages the application's state and handles:
- Location search
- Weather data fetching
- Data processing and formatting

### ContentView
Main view of the application, featuring:
- Search functionality
- Location selection
- Weather display

### WeatherDataView
Displays weather information including:
- Current conditions
- 5-day forecast
- Temperature
- Humidity
- Wind speed
- Precipitation

## API Integration

The app uses two main APIs:
1. OpenWeather Geocoding API for location search
2. MET Norway Weather API for weather
