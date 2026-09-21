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

    init(timeout: Duration = .seconds(10)) {
        self.timeout = timeout
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
                    return Place(
                        name: await Self.placeName(for: location),
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude)
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
