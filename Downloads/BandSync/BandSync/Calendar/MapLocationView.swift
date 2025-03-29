import SwiftUI
import MapKit

// Component for displaying a place on the map with real geocoding
struct MapLocationView: View {
    var address: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.450001, longitude: 30.523333), // Kyiv by default
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var locationAnnotations: [LocationAnnotation] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .padding()

                    Text("Location search error")
                        .font(.headline)

                    Text(error)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()

                    Button("Try again") {
                        errorMessage = nil
                        isLoading = true
                        geocodeAddress()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            } else {
                Map(coordinateRegion: $region, annotationItems: locationAnnotations) { annotation in
                    MapMarker(coordinate: annotation.coordinate, tint: .red)
                }
            }

            Text(address)
                .font(.caption)
                .padding(.vertical, 4)
        }
        .onAppear {
            geocodeAddress()
        }
    }

    func geocodeAddress() {
        // Create geocoder
        let geocoder = CLGeocoder()
        isLoading = true
        errorMessage = nil

        // Geocode the address
        geocoder.geocodeAddressString(address) { placemarks, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Could not find address: \(error.localizedDescription)"
                    return
                }

                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    errorMessage = "Address not found"
                    return
                }

                // Configure map region
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )

                // Create annotation
                let annotation = LocationAnnotation(
                    coordinate: location.coordinate,
                    title: placemark.name ?? "Location",
                    subtitle: getAddressDetails(from: placemark)
                )
                locationAnnotations = [annotation]
            }
        }
    }

    // Get detailed address from placemark
    func getAddressDetails(from placemark: CLPlacemark) -> String {
        var addressComponents: [String] = []

        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }

        if let subThoroughfare = placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }

        if let locality = placemark.locality {
            addressComponents.append(locality)
        }

        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }

        if let postalCode = placemark.postalCode {
            addressComponents.append(postalCode)
        }

        if let country = placemark.country {
            addressComponents.append(country)
        }

        return addressComponents.joined(separator: ", ")
    }
}

// Annotation model for map
struct LocationAnnotation: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var title: String
    var subtitle: String
}
