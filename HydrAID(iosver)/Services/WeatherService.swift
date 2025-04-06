import Foundation

class WeatherService {
    // Base URL for the API
    private let baseURL = "https://api.data.gov.sg/v1/environment"
    
    // Fetch temperature data
    func fetchTemperature() async throws -> WeatherResponse {
        let urlString = "\(baseURL)/air-temperature"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        // Add current date-time as parameter
        let formattedDate = ISO8601DateFormatter().string(from: Date())
        urlComponents.queryItems = [
            URLQueryItem(name: "date_time", value: formattedDate)
        ]
        
        guard let url = urlComponents.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(WeatherResponse.self, from: data)
    }
    
    // Fetch humidity data
    func fetchHumidity() async throws -> WeatherResponse {
        let urlString = "\(baseURL)/relative-humidity"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        // Add current date-time as parameter
        let formattedDate = ISO8601DateFormatter().string(from: Date())
        urlComponents.queryItems = [
            URLQueryItem(name: "date_time", value: formattedDate)
        ]
        
        guard let url = urlComponents.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(WeatherResponse.self, from: data)
    }
    
    // Get latest weather data
    func getLatestWeatherData() async throws -> WeatherData {
        let temperatureData = try await fetchTemperature()
        let humidityData = try await fetchHumidity()
        
        // Find the preferred location or nearby alternatives
        let preferredLocations = ["Nanyang Cres", "Nanyang Crescent", "Nanyang", "NTU", "Jurong", "Boon Lay", "Pioneer", "Jalan Bahar", "Western"]
        
        // Helper function to find a matching station
        func findStation(in stations: [WeatherStation]) -> WeatherStation? {
            for location in preferredLocations {
                if let station = stations.first(where: { $0.name.contains(location) }) {
                    return station
                }
            }
            return stations.first
        }
        
        // Find matching temperature and humidity stations
        let tempStations = temperatureData.metadata.stations
        let humidityStations = humidityData.metadata.stations
        
        let tempStation = findStation(in: tempStations)
        let humidityStation = findStation(in: humidityStations)
        
        // Get the latest readings
        let latestTempItem = temperatureData.items.last!
        let latestHumidityItem = humidityData.items.last!
        
        // Find readings for selected stations
        let temperatureReading = tempStation != nil
            ? latestTempItem.readings.first(where: { $0.station_id == tempStation?.id })
            ?? latestTempItem.readings.first!
            : latestTempItem.readings.first!
        
        let humidityReading = humidityStation != nil
            ? latestHumidityItem.readings.first(where: { $0.station_id == humidityStation?.id })
            ?? latestHumidityItem.readings.first!
            : latestHumidityItem.readings.first!
        
        return WeatherData(
            temperature: temperatureReading.value,
            humidity: humidityReading.value,
            location: "Nanyang Cres, NTU",
            timestamp: latestTempItem.timestamp,
            temperatureUnit: temperatureData.metadata.reading_unit,
            humidityUnit: humidityData.metadata.reading_unit
        )
    }
}

// Error handling
enum WeatherError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
}

// Structs to match the TypeScript interfaces
struct WeatherStation: Codable {
    let id: String
    let device_id: String
    let name: String
    let location: Location
    
    struct Location: Codable {
        let longitude: Double
        let latitude: Double
    }
}

struct Reading: Codable {
    let station_id: String
    let value: Double
}

struct WeatherItem: Codable {
    let timestamp: String
    let readings: [Reading]
}

struct WeatherResponse: Codable {
    let api_info: APIInfo
    let metadata: Metadata
    let items: [WeatherItem]
    
    struct APIInfo: Codable {
        let status: String
    }
    
    struct Metadata: Codable {
        let stations: [WeatherStation]
        let reading_type: String
        let reading_unit: String
    }
}

struct WeatherData: Codable {
    let temperature: Double?
    let humidity: Double?
    let location: String
    let timestamp: String
    let temperatureUnit: String
    let humidityUnit: String
}
