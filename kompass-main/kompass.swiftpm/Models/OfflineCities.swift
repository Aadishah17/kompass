import Foundation
import CoreLocation

struct OfflineCities {
    static let localSF_POIs: [Location] = [
        // Landmarks
        Location(name: "Ferry Building", coordinate: CLLocationCoordinate2D(latitude: 37.7955, longitude: -122.3937), description: "Embarcadero, San Francisco", iconName: "ferry.fill"),
        Location(name: "Coit Tower", coordinate: CLLocationCoordinate2D(latitude: 37.8024, longitude: -122.4058), description: "Telegraph Hill, San Francisco", iconName: "building.2.fill"),
        Location(name: "Oracle Park", coordinate: CLLocationCoordinate2D(latitude: 37.7786, longitude: -122.3893), description: "SoMa, San Francisco", iconName: "sportscourt.fill"),
        Location(name: "SFMOMA", coordinate: CLLocationCoordinate2D(latitude: 37.7857, longitude: -122.4011), description: "SoMa, San Francisco", iconName: "paintpalette.fill"),
        Location(name: "Salesforce Park", coordinate: CLLocationCoordinate2D(latitude: 37.7885, longitude: -122.3965), description: "SoMa, San Francisco", iconName: "leaf.fill"),
        Location(name: "Union Square", coordinate: CLLocationCoordinate2D(latitude: 37.7880, longitude: -122.4075), description: "Downtown, San Francisco", iconName: "bag.fill"),
        Location(name: "Chinatown Gate", coordinate: CLLocationCoordinate2D(latitude: 37.7906, longitude: -122.4056), description: "Chinatown, San Francisco", iconName: "building.columns.fill"),
        Location(name: "Transamerica Pyramid", coordinate: CLLocationCoordinate2D(latitude: 37.7952, longitude: -122.4028), description: "Financial District, San Francisco", iconName: "triangle.fill"),
        Location(name: "Lombard Street", coordinate: CLLocationCoordinate2D(latitude: 37.8021, longitude: -122.4187), description: "Russian Hill, San Francisco", iconName: "road.lanes"),
        Location(name: "Fisherman's Wharf", coordinate: CLLocationCoordinate2D(latitude: 37.8080, longitude: -122.4177), description: "Fisherman's Wharf, San Francisco", iconName: "fish.fill"),
        Location(name: "Pier 39", coordinate: CLLocationCoordinate2D(latitude: 37.8087, longitude: -122.4098), description: "Fisherman's Wharf, San Francisco", iconName: "water.waves"),
        Location(name: "Ghirardelli Square", coordinate: CLLocationCoordinate2D(latitude: 37.8059, longitude: -122.4228), description: "Aquatic Park, San Francisco", iconName: "cup.and.saucer.fill"),
        Location(name: "Moscone Center", coordinate: CLLocationCoordinate2D(latitude: 37.7842, longitude: -122.4016), description: "SoMa, San Francisco", iconName: "building.fill"),
        Location(name: "Yerba Buena Gardens", coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4025), description: "SoMa, San Francisco", iconName: "leaf.fill"),
        Location(name: "AT&T Park", coordinate: CLLocationCoordinate2D(latitude: 37.7786, longitude: -122.3893), description: "SoMa, San Francisco", iconName: "sportscourt.fill"),
        
        // Hotels
        Location(name: "Hilton San Francisco", coordinate: CLLocationCoordinate2D(latitude: 37.7862, longitude: -122.4104), description: "Union Square, San Francisco", iconName: "bed.double.fill"),
        Location(name: "Marriott Marquis", coordinate: CLLocationCoordinate2D(latitude: 37.7853, longitude: -122.4031), description: "SoMa, San Francisco", iconName: "bed.double.fill"),
        Location(name: "The St. Regis", coordinate: CLLocationCoordinate2D(latitude: 37.7861, longitude: -122.4009), description: "SoMa, San Francisco", iconName: "bed.double.fill"),
        Location(name: "Hotel Nikko", coordinate: CLLocationCoordinate2D(latitude: 37.7862, longitude: -122.4099), description: "Union Square, San Francisco", iconName: "bed.double.fill"),
        
        // Food & Drink
        Location(name: "Boudin Bakery", coordinate: CLLocationCoordinate2D(latitude: 37.8088, longitude: -122.4158), description: "Fisherman's Wharf, San Francisco", iconName: "fork.knife"),
        Location(name: "The Slanted Door", coordinate: CLLocationCoordinate2D(latitude: 37.7955, longitude: -122.3939), description: "Ferry Building, San Francisco", iconName: "fork.knife"),
        Location(name: "Blue Bottle Coffee", coordinate: CLLocationCoordinate2D(latitude: 37.7822, longitude: -122.4070), description: "Mint Plaza, San Francisco", iconName: "cup.and.saucer.fill"),
        Location(name: "Starbucks Reserve", coordinate: CLLocationCoordinate2D(latitude: 37.7877, longitude: -122.4075), description: "Union Square, San Francisco", iconName: "cup.and.saucer.fill"),
        
        // Transit
        Location(name: "Embarcadero Station", coordinate: CLLocationCoordinate2D(latitude: 37.7930, longitude: -122.3970), description: "BART/Muni, San Francisco", iconName: "tram.fill"),
        Location(name: "Montgomery Station", coordinate: CLLocationCoordinate2D(latitude: 37.7894, longitude: -122.4017), description: "BART/Muni, San Francisco", iconName: "tram.fill"),
        Location(name: "Powell Station", coordinate: CLLocationCoordinate2D(latitude: 37.7844, longitude: -122.4079), description: "BART/Muni, San Francisco", iconName: "tram.fill"),
        Location(name: "Civic Center Station", coordinate: CLLocationCoordinate2D(latitude: 37.7796, longitude: -122.4138), description: "BART/Muni, San Francisco", iconName: "tram.fill"),
        Location(name: "Caltrain Station", coordinate: CLLocationCoordinate2D(latitude: 37.7764, longitude: -122.3943), description: "SoMa, San Francisco", iconName: "train.side.front.car"),
        
        // Parks
        Location(name: "Washington Square Park", coordinate: CLLocationCoordinate2D(latitude: 37.8005, longitude: -122.4103), description: "North Beach, San Francisco", iconName: "leaf.fill"),
        Location(name: "South Park", coordinate: CLLocationCoordinate2D(latitude: 37.7822, longitude: -122.3937), description: "SoMa, San Francisco", iconName: "leaf.fill"),
        Location(name: "Sue Bierman Park", coordinate: CLLocationCoordinate2D(latitude: 37.7950, longitude: -122.3970), description: "Embarcadero, San Francisco", iconName: "leaf.fill"),
        
        // Shopping
        Location(name: "Westfield Centre", coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4069), description: "Market St, San Francisco", iconName: "bag.fill"),
        Location(name: "Macy's", coordinate: CLLocationCoordinate2D(latitude: 37.7876, longitude: -122.4072), description: "Union Square, San Francisco", iconName: "bag.fill"),
        Location(name: "Nordstrom", coordinate: CLLocationCoordinate2D(latitude: 37.7854, longitude: -122.4068), description: "Market St, San Francisco", iconName: "bag.fill"),
        
        // Cultural
        Location(name: "City Lights Bookstore", coordinate: CLLocationCoordinate2D(latitude: 37.7976, longitude: -122.4065), description: "North Beach, San Francisco", iconName: "book.fill"),
        Location(name: "Asian Art Museum", coordinate: CLLocationCoordinate2D(latitude: 37.7801, longitude: -122.4163), description: "Civic Center, San Francisco", iconName: "paintpalette.fill"),
        Location(name: "Contemporary Jewish Museum", coordinate: CLLocationCoordinate2D(latitude: 37.7858, longitude: -122.4014), description: "SoMa, San Francisco", iconName: "building.columns.fill"),
        
        // Neighborhoods (for general area search)
        Location(name: "North Beach", coordinate: CLLocationCoordinate2D(latitude: 37.7998, longitude: -122.4082), description: "Neighborhood, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "SoMa", coordinate: CLLocationCoordinate2D(latitude: 37.7785, longitude: -122.3950), description: "South of Market, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "Financial District", coordinate: CLLocationCoordinate2D(latitude: 37.7946, longitude: -122.3999), description: "Neighborhood, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "Nob Hill", coordinate: CLLocationCoordinate2D(latitude: 37.7930, longitude: -122.4161), description: "Neighborhood, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "Russian Hill", coordinate: CLLocationCoordinate2D(latitude: 37.8011, longitude: -122.4194), description: "Neighborhood, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "Telegraph Hill", coordinate: CLLocationCoordinate2D(latitude: 37.8024, longitude: -122.4058), description: "Neighborhood, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "Tenderloin", coordinate: CLLocationCoordinate2D(latitude: 37.7847, longitude: -122.4141), description: "Neighborhood, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "Chinatown", coordinate: CLLocationCoordinate2D(latitude: 37.7941, longitude: -122.4078), description: "Neighborhood, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "Embarcadero", coordinate: CLLocationCoordinate2D(latitude: 37.7941, longitude: -122.3938), description: "Waterfront, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "Market Street", coordinate: CLLocationCoordinate2D(latitude: 37.7853, longitude: -122.4068), description: "Main Avenue, San Francisco", iconName: "mappin.circle.fill"),
        
        // More Famous Landmarks
        Location(name: "Golden Gate Bridge", coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783), description: "Golden Gate, San Francisco", iconName: "bridge.fill"),
        Location(name: "Alcatraz Island", coordinate: CLLocationCoordinate2D(latitude: 37.8270, longitude: -122.4230), description: "San Francisco Bay", iconName: "lock.fill"),
        Location(name: "Palace of Fine Arts", coordinate: CLLocationCoordinate2D(latitude: 37.8020, longitude: -122.4486), description: "Marina District, San Francisco", iconName: "building.columns.fill"),
        Location(name: "Painted Ladies", coordinate: CLLocationCoordinate2D(latitude: 37.7762, longitude: -122.4330), description: "Alamo Square, San Francisco", iconName: "house.fill"),
        Location(name: "Twin Peaks", coordinate: CLLocationCoordinate2D(latitude: 37.7544, longitude: -122.4477), description: "Twin Peaks, San Francisco", iconName: "mountain.2.fill"),
        Location(name: "Exploratorium", coordinate: CLLocationCoordinate2D(latitude: 37.8009, longitude: -122.3986), description: "Embarcadero, San Francisco", iconName: "atom"),
        Location(name: "Legion of Honor", coordinate: CLLocationCoordinate2D(latitude: 37.7845, longitude: -122.5008), description: "Lincoln Park, San Francisco", iconName: "building.columns.fill"),
        Location(name: "Presidio", coordinate: CLLocationCoordinate2D(latitude: 37.7984, longitude: -122.4666), description: "National Park, San Francisco", iconName: "tree.fill"),
        Location(name: "Japantown", coordinate: CLLocationCoordinate2D(latitude: 37.7852, longitude: -122.4296), description: "Neighborhood, San Francisco", iconName: "mappin.circle.fill"),
        Location(name: "Mission Dolores Park", coordinate: CLLocationCoordinate2D(latitude: 37.7597, longitude: -122.4270), description: "Mission District, San Francisco", iconName: "leaf.fill")
    ]
    
    static let all: [Location] = localSF_POIs
}
