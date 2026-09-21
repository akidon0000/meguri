import Foundation

@testable import Meguri

final class FakeLocation: LocationProviding, @unchecked Sendable {
    let place: Place?

    init(place: Place? = Place(name: "Somewhere", latitude: 1, longitude: 2)) {
        self.place = place
    }

    func currentPlace() async -> Place? { place }
}
