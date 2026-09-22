import CoreLocation
import Foundation

struct Place: Sendable, Equatable {
    var name: String?
    var latitude: Double
    var longitude: Double
}

protocol LocationProviding: Sendable {
    func currentPlace() async -> Place?
}

final class CoreLocationService: LocationProviding {
    @MainActor private let manager = CLLocationManager()
    private let timeout: Duration
    private let geocodeTimeout: Duration

    init(timeout: Duration = .seconds(10), geocodeTimeout: Duration = .seconds(4)) {
        self.timeout = timeout
        self.geocodeTimeout = geocodeTimeout
    }

    func currentPlace() async -> Place? {
        await withTimeout(timeout) { await self.resolve() }
    }

    private func resolve() async -> Place? {
        await MainActor.run {
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            }
        }

        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location {
                    var place = Place(
                        name: nil,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude)
                    place.name = await withTimeout(geocodeTimeout) {
                        await Self.placeName(for: location)
                    }
                    return place
                }
                if update.authorizationDenied || update.authorizationDeniedGlobally
                    || update.locationUnavailable
                {
                    return nil
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func placeName(for location: CLLocation) async -> String? {
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return nil
        }
        let candidates = [
            placemark.name, placemark.locality, placemark.administrativeArea, placemark.country
        ]
        var seen = Set<String>()
        let parts = candidates.compactMap { $0 }.filter { !$0.isEmpty && seen.insert($0).inserted }
        return parts.isEmpty ? nil : parts.prefix(3).joined(separator: ", ")
    }
}
