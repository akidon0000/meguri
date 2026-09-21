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
    private let timeout: Duration
    private let geocodeTimeout: Duration

    init(timeout: Duration = .seconds(10), geocodeTimeout: Duration = .seconds(4)) {
        self.timeout = timeout
        self.geocodeTimeout = geocodeTimeout
    }

    func currentPlace() async -> Place? {
        await withTaskGroup(of: Place?.self) { group in
            group.addTask { await self.resolve() }
            group.addTask { [timeout] in
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next().flatMap { $0 }
            group.cancelAll()
            return first
        }
    }

    private func resolve() async -> Place? {
        await MainActor.run {
            let manager = CLLocationManager()
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
                    place.name = await Self.placeName(for: location, timeout: geocodeTimeout)
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

    // Bounded separately so a slow geocoder cannot cost the coordinates we already have.
    private static func placeName(for location: CLLocation, timeout: Duration) async -> String? {
        let placemark = await withTaskGroup(of: CLPlacemark?.self) { group in
            group.addTask { try? await CLGeocoder().reverseGeocodeLocation(location).first }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next().flatMap { $0 }
            group.cancelAll()
            return first
        }
        guard let placemark else { return nil }
        let candidates = [
            placemark.name, placemark.locality, placemark.administrativeArea, placemark.country
        ]
        var seen = Set<String>()
        let parts = candidates.compactMap { $0 }.filter { !$0.isEmpty && seen.insert($0).inserted }
        return parts.isEmpty ? nil : parts.prefix(3).joined(separator: ", ")
    }
}
