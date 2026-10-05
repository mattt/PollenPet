import Foundation
import RealityKit
import Testing
@testable import PollenPet

@Suite("Microduck appearance") @MainActor
struct MicroduckAppearanceTests {
    @Test func presetsAndInvalidStorage() throws {
        for preset in MicroduckColor.presets {
            let value = MicroduckAppearance(preset: preset)
            #expect(value.head == preset && value.body == preset)
            #expect(value.beak == .orange && value.feet == .orange)
            #expect(MicroduckAppearance.restored(from: try JSONEncoder().encode(value)) == value)
        }
        for data in [nil, Data(), Data("{}".utf8),
                     Data(#"{"schemaVersion":2,"preset":"cream","head":"cream","body":"cream","beak":"orange","feet":"orange"}"#.utf8),
                     Data(#"{"schemaVersion":1,"head":"unknown","body":"cream","beak":"orange","feet":"orange"}"#.utf8)] {
            #expect(MicroduckAppearance.restored(from: data) == .cream)
        }
    }

    @Test func changesSaveImmediatelyWithoutChangingConversation() throws {
        let suite = "appearance-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MicroduckAppearanceStore(defaults: defaults)
        let conversation = Conversation(playback: PlaybackController(audio: EngineAudioOutput(), automaticTick: false))
        let performanceID = conversation.performanceID
        let performance = conversation.performance
        store.save(.init(preset: .sky))
        #expect(store.appearance.head == .sky)
        #expect(MicroduckAppearanceStore(defaults: defaults).appearance == store.appearance)
        var appearance = store.appearance
        appearance[.feet] = .yellow
        store.save(appearance)
        #expect(store.appearance.preset == nil)
        #expect(MicroduckAppearanceStore(defaults: defaults).appearance == appearance)
        #expect(conversation.performanceID == performanceID)
        #expect(conversation.performance == performance)
        store.save(.cream)
        #expect(store.appearance == .cream)
        #expect(MicroduckAppearanceStore(defaults: defaults).appearance == .cream)
    }

    @Test func colorsChangeOnlyMappedMeshesAndPreserveTransforms() async throws {
        let url = try #require(Bundle.main.url(forResource: "model", withExtension: "usdz", subdirectory: "Models/microduck"))
        let root = try await Entity(contentsOf: url)
        let materials = try MicroduckMaterials(root: root)
        func allEntities(_ root: Entity) -> [Entity] { [root] + root.children.flatMap(allEntities) }
        let entities = allEntities(root)
        let transforms = entities.map(\.transform)
        materials.apply(.cream)
        func colors() -> [String: [String]] {
            Dictionary(uniqueKeysWithValues: entities.compactMap { entity in
                guard let model = entity as? ModelEntity else { return nil }
                return (String(describing: ObjectIdentifier(entity)), (model.model?.materials ?? []).map {
                    guard let material = $0 as? PhysicallyBasedMaterial else { return String(describing: $0) }
                    return String(describing: material.baseColor.tint)
                })
            })
        }
        for part in MicroduckPart.allCases {
            materials.apply(.cream)
            let before = colors()
            var appearance = MicroduckAppearance.cream
            appearance[part] = .graphite
            materials.apply(appearance)
            let after = colors()
            for entity in entities where entity is ModelEntity {
                let id = String(describing: ObjectIdentifier(entity))
                if part.meshNames.contains(entity.name) { #expect(before[id] != after[id]) }
                else { #expect(before[id] == after[id]) }
            }
            #expect(entities.map(\.transform) == transforms)
        }
    }
}
