import Foundation
import SwiftData
import SwiftUI

struct AppDependencies {
    var perception: any ImagePerceiving = VisionImagePerception()
    var generator: any InsightGenerating = FoundationModelsInsightGenerator()
    var location: any LocationProviding = CoreLocationService()
    var imageStore: any ImageStoring = FileImageStore.default

    @MainActor
    func makeAnalyzeViewModel(modelContext: ModelContext) -> AnalyzeViewModel {
        AnalyzeViewModel(
            perception: perception, generator: generator, location: location,
            imageStore: imageStore, modelContext: modelContext)
    }
}

extension EnvironmentValues {
    @Entry var dependencies = AppDependencies()
}
