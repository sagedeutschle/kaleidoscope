import Foundation

/// Curated 5-letter answer and guess words for the Wordgame facet.
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

    static let approvedGuesses: [String] = Array(Set(all + commonApprovedGuesses)).sorted()

    private static let commonApprovedGuesses: [String] = [
        "about", "above", "abuse", "actor", "acute", "adieu", "admit", "adopt", "adult", "after",
        "again", "agent", "agile", "aglow", "agony", "agree", "ahead", "aisle", "alarm", "album",
        "alert", "alike", "alive", "allow", "alone", "along", "alter", "amaze", "among", "anger",
        "ankle", "apart", "apple", "apply", "arena", "argue", "arise", "aroma", "aside", "asset",
        "attic", "avoid", "awake", "award", "aware", "awful", "badge", "badly", "baker", "basic",
        "basis", "beard", "beast", "begin", "being", "belly", "bench", "berry", "birth", "black",
        "blade", "blank", "blast", "blend", "blind", "block", "blood", "board", "boost", "brain",
        "brand", "break", "brief", "bring", "broad", "brown", "brush", "build", "built", "burst",
        "buyer", "cabin", "cable", "carry", "catch", "cause", "chain", "chalk", "cheap", "cheer",
        "chest", "chief", "child", "chill", "choir", "civil", "claim", "class", "clerk", "click",
        "climb", "clock", "close", "coach", "coast", "color", "could", "count", "court", "cover",
        "craft", "crash", "cream", "crime", "cross", "crowd", "crown", "daily", "delay", "delta",
        "depth", "dirty", "doubt", "dozen", "draft", "drain", "drama", "drink", "drive", "eager",
        "early", "earth", "eight", "elite", "empty", "enemy", "enjoy", "enter", "entry", "equal",
        "error", "event", "every", "exact", "exist", "faith", "false", "fault", "fiber", "field",
        "final", "first", "flash", "floor", "focus", "force", "forth", "found", "frame", "fresh",
        "front", "fruit", "glass", "glory", "grace", "grade", "grain", "grand", "grant", "grass",
        "great", "group", "guard", "guest", "guide", "habit", "heavy", "honor", "horse", "human",
        "ideal", "issue", "jeans", "judge", "juice", "known", "large", "later", "laugh", "layer",
        "learn", "least", "level", "lobby", "local", "logic", "loose", "lucky", "lunch", "major",
        "maker", "match", "maybe", "metal", "minor", "model", "motor", "nerve", "night", "noise",
        "novel", "nurse", "order", "other", "outer", "paint", "panel", "paper", "party", "pause",
        "phase", "phone", "piece", "pilot", "pitch", "place", "plain", "point", "porch", "power",
        "press", "price", "prime", "print", "prize", "proof", "proud", "quiet", "quite", "radio",
        "raise", "range", "rapid", "ratio", "reach", "ready", "realm", "reply", "right", "round",
        "route", "scale", "scare", "scene", "scope", "score", "sense", "serve", "seven", "shade",
        "shall", "shape", "share", "sharp", "sheet", "shift", "shirt", "shock", "short", "sight",
        "skill", "sleep", "small", "smart", "solid", "solve", "sound", "south", "space", "spare",
        "speak", "speed", "spell", "spend", "split", "sport", "staff", "stage", "stand", "start",
        "state", "steal", "steel", "stick", "still", "stock", "store", "story", "study", "style",
        "sugar", "super", "sweet", "taken", "taste", "teach", "tears", "thank", "their", "theme",
        "there", "thick", "thing", "think", "third", "those", "three", "throw", "tight", "today",
        "topic", "total", "touch", "tower", "track", "trade", "trial", "truck", "trust", "truth",
        "twice", "under", "upset", "urban", "usage", "usual", "value", "video", "visit", "voice",
        "waste", "watch", "water", "where", "which", "white", "whole", "whose", "woman", "words",
        "worth", "would", "write", "wrong", "young"
    ]
}
