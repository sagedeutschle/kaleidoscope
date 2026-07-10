import AVFoundation
import XCTest
@testable import Prismet

final class SoundSynthTests: XCTestCase {
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    func testRenderBufferForEveryCueIsNonEmptyAndInRange() {
        for cue in SoundCue.allCases {
            guard let buffer = SoundEngine.renderBuffer(for: cue, format: format) else {
                XCTFail("\(cue) rendered a nil buffer")
                continue
            }
            XCTAssertGreaterThan(buffer.frameLength, 0, "\(cue) rendered an empty buffer")
            let samples = buffer.floatChannelData![0]
            for i in 0..<Int(buffer.frameLength) {
                let sample = samples[i]
                XCTAssertTrue(sample.isFinite, "\(cue) produced a non-finite sample at \(i)")
                XCTAssertLessThanOrEqual(abs(sample), 1.0, "\(cue) sample outside [-1, 1] at \(i)")
            }
        }
    }

    func testRenderedLengthCoversTheRequestedMotif() {
        let cue = SoundCue.win
        guard let buffer = SoundEngine.renderBuffer(for: cue, format: format) else {
            return XCTFail("win rendered nil")
        }
        let minExpected = Double(cue.notes.count) * cue.noteDuration * format.sampleRate
        XCTAssertGreaterThanOrEqual(Double(buffer.frameLength), minExpected * 0.9,
                                    "rendered buffer shorter than the motif it should contain")
    }
}
