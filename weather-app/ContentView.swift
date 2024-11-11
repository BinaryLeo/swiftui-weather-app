
import SwiftUI
import Combine

// Data structures
struct GeocodingResult: Codable, Identifiable {
    let id = UUID()
    let name: String
    let lat: Double
    let lon: Double
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case name, lat, lon, country
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        lat = try container.decode(Double.self, forKey: .lat)
        lon = try container.decode(Double.self, forKey: .lon)
        country = try container.decodeIfPresent(String.self, forKey: .country)
    }
}

struct WeatherResponse: Codable {
    let type: String
    let geometry: Geometry
    let properties: Properties
}

struct Geometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct Properties: Codable {
    let meta: Meta
    let timeseries: [TimeseriesData]
}

struct Meta: Codable {
    let updatedAt: String
    let units: Units
    
    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case units
    }
}

struct Units: Codable {
    let airPressureAtSeaLevel: String
    let airTemperature: String
    let cloudAreaFraction: String
    let precipitationAmount: String
    let relativeHumidity: String
    let windFromDirection: String
    let windSpeed: String
    
    enum CodingKeys: String, CodingKey {
        case airPressureAtSeaLevel = "air_pressure_at_sea_level"
        case airTemperature = "air_temperature"
        case cloudAreaFraction = "cloud_area_fraction"
        case precipitationAmount = "precipitation_amount"
        case relativeHumidity = "relative_humidity"
        case windFromDirection = "wind_from_direction"
        case windSpeed = "wind_speed"
    }
}

struct TimeseriesData: Codable {
    let time: String
    let data: WeatherData
}

struct WeatherData: Codable {
    let instant: InstantData
    let next1Hours: NextHours?
    let next6Hours: NextHours?
    
    enum CodingKeys: String, CodingKey {
        case instant
        case next1Hours = "next_1_hours"
        case next6Hours = "next_6_hours"
    }
}

struct InstantData: Codable {
    let details: WeatherDetails
}

struct WeatherDetails: Codable {
    let airTemperature: Double
    let relativeHumidity: Double
    let windSpeed: Double
    
    enum CodingKeys: String, CodingKey {
        case airTemperature = "air_temperature"
        case relativeHumidity = "relative_humidity"
        case windSpeed = "wind_speed"
    }
}

struct NextHours: Codable {
    let summary: Summary
    let details: PrecipitationDetails
}

struct Summary: Codable {
    let symbolCode: String
    
    enum CodingKeys: String, CodingKey {
        case symbolCode = "symbol_code"
    }
}

struct PrecipitationDetails: Codable {
    let precipitationAmount: Double
    
    enum CodingKeys: String, CodingKey {
        case precipitationAmount = "precipitation_amount"
    }
}

struct WeatherDayData: Identifiable {
    let id = UUID()
    let day: String
    let temperature: Double
    let humidity: Double
    let windSpeed: Double
    let precipitationAmount: Double
    let symbolCode: String
}

class WeatherViewModel: ObservableObject {
    @Published var weatherData: [WeatherDayData] = []
    @Published var searchText = ""
    @Published var searchResults: [GeocodingResult] = []
    @Published var selectedLocation: GeocodingResult?
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiKey = Config.apiKey
    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .sink { [weak self] searchTerm in
                self?.searchLocations(searchTerm)
            }
            .store(in: &cancellables)
    }

    func searchLocations(_ searchTerm: String) {
            let urlString = "https://api.openweathermap.org/geo/1.0/direct?q=\(searchTerm)&limit=5&appid=\(apiKey)"
            guard let url = URL(string: urlString) else {
                self.errorMessage = "Invalid search URL"
                return
            }

            URLSession.shared.dataTaskPublisher(for: url)
                .map(\.data)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = "Search error: \(error.localizedDescription)"
                    }
                } receiveValue: { [weak self] data in
                    // Debug: Print raw response
                    print("Raw API Response:")
                    print(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")
                    
                    do {
                        let results = try JSONDecoder().decode([GeocodingResult].self, from: data)
                        self?.searchResults = results
                        self?.errorMessage = nil
                    } catch {
                        self?.errorMessage = "Failed to decode search results: \(error.localizedDescription)"
                        self?.searchResults = []
                    }
                }
                .store(in: &cancellables)
        }

    func fetchWeather(for location: GeocodingResult) {
        print("Fetching weather for: \(location.name), Lat: \(location.lat), Lon: \(location.lon)")
        selectedLocation = location
        let urlString = "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(location.lat)&lon=\(location.lon)"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid weather URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("WeatherApp/1.0 your@email.com", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "Weather error: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] data in
                print("Weather API Raw Response:")
                print(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")
                
                do {
                    let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
                    self?.processWeatherData(response)
                    self?.errorMessage = nil
                } catch {
                    self?.errorMessage = "Failed to decode weather data: \(error.localizedDescription)"
                    print("Decoding error: \(error)")
                }
            }
            .store(in: &cancellables)
    }
    
    private func processWeatherData(_ response: WeatherResponse) {
        print("Processing weather data")
        let forecastData = response.properties.timeseries.prefix(5)
        self.weatherData = forecastData.enumerated().map { index, data in
            let weatherDay = WeatherDayData(
                day: self.getDayOfWeek(for: index),
                temperature: data.data.instant.details.airTemperature,
                humidity: data.data.instant.details.relativeHumidity,
                windSpeed: data.data.instant.details.windSpeed,
                precipitationAmount: data.data.next6Hours?.details.precipitationAmount ?? 0,
                symbolCode: data.data.next1Hours?.summary.symbolCode ?? "cloud.sun.fill"
            )
            print("Processed day: \(weatherDay.day), Temp: \(weatherDay.temperature)")
            return weatherDay
        }
        print("Processed \(self.weatherData.count) days of weather data")
    }

    
    func getDayOfWeek(for index: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

struct ContentView: View {
    @StateObject private var viewModel = WeatherViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.blue, .white]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                SearchBar(text: $viewModel.searchText)
                    .padding()
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                if !viewModel.searchResults.isEmpty {
                    List(viewModel.searchResults) { location in
                        Button(action: {
                            viewModel.fetchWeather(for: location)
                        }) {
                            Text(location.country != nil ? "\(location.name), \(location.country!)" : location.name)
                        }
                    }
                    .frame(height: 200)
                }
                
                if let selectedLocation = viewModel.selectedLocation {
                    Text("\(selectedLocation.name), \(selectedLocation.country ?? "")")
                        .font(.system(size: 32, weight: .medium, design: .default))
                        .foregroundColor(.white)
                        .padding()
                    
                    if viewModel.weatherData.isEmpty {
                        Text("Loading weather data...")
                            .foregroundColor(.white)
                    } else {
                        WeatherDataView(weatherData: viewModel.weatherData)
                    }
                }
                
                Spacer()
            }
        }
    }
}

struct WeatherDataView: View {
    let weatherData: [WeatherDayData]
    
    var body: some View {
        VStack {
            if let currentWeather = weatherData.first {
                WeatherView(weatherData: currentWeather, isLarge: true)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(weatherData.dropFirst()) { weatherData in
                        WeatherView(weatherData: weatherData, isLarge: false)
                    }
                }
                .padding()
            }
            .frame(height: 200)
        }
    }
}

struct WeatherView: View {
    let weatherData: WeatherDayData
    let isLarge: Bool
    
    var body: some View {
        VStack {
            Text(weatherData.day)
                .font(isLarge ? .title : .headline)
            Image(systemName: weatherData.symbolCode)
                .font(isLarge ? .system(size: 100) : .system(size: 50))
            Text("\(Int(weatherData.temperature))°C")
                .font(isLarge ? .title : .body)
            if isLarge {
                Text("Humidity: \(Int(weatherData.humidity))%")
                Text("Wind: \(Int(weatherData.windSpeed)) m/s")
                Text("Precipitation: \(weatherData.precipitationAmount, specifier: "%.1f") mm")
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            TextField("Search location", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

