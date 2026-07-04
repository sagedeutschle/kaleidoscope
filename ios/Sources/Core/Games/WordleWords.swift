import Foundation

/// Curated 5-letter answer words for the Wordle facet. Guesses aren't dictionary-gated
/// (any 5 letters are accepted), so this only needs to be a pool of fair answers.
enum WordleWords {
    static let all: [String] = [
        "crane", "slate", "audio", "house", "money", "train", "light", "world", "music", "happy",
        "green", "ocean", "table", "chair", "plant", "stone", "river", "cloud", "dream", "smile",
        "beach", "bread", "candy", "dance", "eagle", "flame", "grape", "honey", "ivory", "jewel",
        "knife", "lemon", "maple", "north", "olive", "peace", "queen", "robin", "spice", "tiger",
        "uncle", "vivid", "wagon", "youth", "zebra", "amber", "blaze", "charm", "dwell", "ember",
        "frost", "glide", "haste", "input", "joker", "kneel", "lunar", "mirth", "noble", "orbit",
        "pearl", "quilt", "raven", "shine", "torch", "unity", "vault", "whale", "xenon", "yield",
        "abide", "brave", "creek", "daisy", "elder", "fable", "giant", "heart", "image", "joint",
        "karma", "laser", "magic", "ninja", "opera", "piano", "quirk", "ridge", "swift", "twine",
        "ultra", "venom", "woven", "yacht", "angel", "bloom", "clean", "drift", "extra", "fairy",
        "gleam", "hatch", "index", "jolly", "kayak", "ledge", "moral", "nudge", "ozone", "pride",
        "quest", "rural", "salty", "trace", "udder", "vocal", "wheat", "yearn", "adore", "blush"
    ]
}
