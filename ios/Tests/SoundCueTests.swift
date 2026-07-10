import XCTest
@testable import Prismet

final class SoundCueTests: XCTestCase {
    func testEveryCueHasAtLeastOnePositiveFrequencyNote() {
        for cue in SoundCue.allCases {
            XCTAssertFalse(cue.notes.isEmpty, "\(cue) has no notes")
            XCTAssertTrue(cue.notes.allSatisfy { $0 > 0 }, "\(cue) has a non-positive frequency")
        }
    }

    func testEveryCueHasPositiveNoteDuration() {
        for cue in SoundCue.allCases {
            XCTAssertGreaterThan(cue.noteDuration, 0, "\(cue) noteDuration must be > 0")
        }
    }

    func testWinAndLoseAreMultiNoteMotifs() {
        XCTAssertGreaterThanOrEqual(SoundCue.win.notes.count, 3, "win should be a rising motif")
        XCTAssertGreaterThanOrEqual(SoundCue.lose.notes.count, 2, "lose should descend")
    }

    func testAllCuesPresent() {
        // 9 synthesized + 4 sampled (piece move/capture, tile slide/merge).
        XCTAssertEqual(SoundCue.allCases.count, 13)
    }

    func testSampledCuesDeclareAResourceFile() {
        let sampled: [SoundCue] = [.pieceMove, .pieceCapture, .tileSlide, .tileMerge]
        for cue in sampled {
            XCTAssertNotNil(cue.soundFile, "\(cue) should name a bundled sound file")
        }
        // Synthesized cues have no file.
        XCTAssertNil(SoundCue.move.soundFile)
    }
}
