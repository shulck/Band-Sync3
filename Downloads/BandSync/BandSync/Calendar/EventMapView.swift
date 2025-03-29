import SwiftUI
import MapKit

struct EventMapView: View {
    var address: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.450001, longitude: 30.523333),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var annotations: [EventAnnotation] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var placemark: CLPlacemark? = nil

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading map...")
                    .padding()
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 50))
                        .padding()

                    Text("Map loading error")
                        .font(.headline)

                    Text(error)
                        .foregroundColor(.secondary)

                    Button("Retry") {
                        geocodeAddress()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                }
            } else {
                Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)

                            Text(annotation.title)
                                .font(.caption)
                                .padding(4)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                }

                if let placemark = placemark {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(placemark.name ?? "Event location")
                            .font(.headline)

                        if let locality = placemark.locality, let country = placemark.country {
                            Text("\(locality), \(country)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white)
                }
            }
        }
        .onAppear {
            geocodeAddress()
        }
    }

    func geocodeAddress() {
        isLoading = true
        errorMessage = nil

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    self.errorMessage = "Could not find coordinates for the specified address"
                    return
                }

                self.placemark = placemark

                // Update map region
                self.region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )

                // Create annotation
                let annotation = EventAnnotation(
                    coordinate: location.coordinate,
                    title: placemark.name ?? "Event",
                    subtitle: self.address
                )

                self.annotations = [annotation]
            }
        }
    }
}

struct EventAnnotation: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var title: String
    var subtitle: String
}
