import AppKit
import Foundation
import Testing
@testable import PollenPet

@Suite("Bundled characters")
struct ModelAssetTests {
    @Test func rosterListsBothRobots() {
        #expect(PetID.allCases == [.microduck, .reachyMini])
        #expect(PetID.allCases.map(\.name) == ["Microduck", "Reachy Mini"])
        #expect(PetID(rawValue: "reachy-mini") == .reachyMini)
    }

    @Test(arguments: PetID.allCases) func modelFramingAndPortraitAreBundled(pet: PetID) throws {
        let model = Bundle.main.url(forResource: "model", withExtension: "usdz", subdirectory: "Models/\(pet.rawValue)")
        #expect(model != nil)
        let url = try #require(Bundle.main.url(forResource: "framing", withExtension: "json",
                                               subdirectory: "Models/\(pet.rawValue)"))
        let framing = try JSONDecoder().decode([String: [Double]].self, from: Data(contentsOf: url))
        let minimum = try #require(framing["min"])
        let maximum = try #require(framing["max"])
        #expect(minimum.count == 3 && maximum.count == 3)
        #expect((minimum + maximum).allSatisfy { $0.isFinite })
        #expect(maximum[0] > minimum[0] && maximum[1] > minimum[1] && maximum[2] > minimum[2])
        let portrait = try #require(Bundle.main.url(forResource: pet.rawValue, withExtension: "png", subdirectory: "Portraits"))
        #expect(NSImage(contentsOf: portrait) != nil)
    }

    @Test(arguments: PetID.allCases) func everySceneHasTwoRepliesWithTwoLinesEach(pet: PetID) {
        for sceneID in SceneID.allCases {
            let scene = SceneLibrary.scene(sceneID, for: pet)
            #expect(!scene.opening.text.isEmpty)
            #expect(scene.choices.map(\.id) == [0, 1])
            for choice in scene.choices {
                #expect(!choice.text.isEmpty)
                #expect(choice.response.count == 2)
                #expect(choice.response.allSatisfy { !$0.text.isEmpty })
            }
        }
    }
}
