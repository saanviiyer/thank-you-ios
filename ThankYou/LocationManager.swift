import CoreLocation
import Foundation

@MainActor final class LocationManager: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var place: Place?
    @Published var isLocating = false
    @Published var errorMessage: String?
    private let manager = CLLocationManager()
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }

    func requestLocation() {
        isLocating = true; errorMessage = nil
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { isLocating = false; errorMessage = "Location access is turned off." }
        else { manager.requestLocation() }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            errorMessage = "Location access is turned off. You can enable it in Settings."
        case .notDetermined:
            break
        @unknown default:
            isLocating = false
            errorMessage = "Location is unavailable right now."
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        CLGeocoder().reverseGeocodeLocation(location) { marks, error in
            let mark = marks?.first
            let name = mark?.name ?? "Current location"
            let locality = [mark?.locality, mark?.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            Task { @MainActor in
                self.place = Place(name: name, locality: locality.isEmpty ? "Nearby" : locality, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                self.isLocating = false
                if error != nil { self.errorMessage = "The location name was unavailable, so the current coordinates were attached." }
            }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in isLocating = false; errorMessage = "We couldn't find your location." }
    }
}
