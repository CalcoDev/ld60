class_name GleepGlorpLanguages

enum Language {
    CONSONANT,
    SYLLABLE,
    NUMERIC,
    STATIC,
    ARROWS
}

const CONSONANTS = "qzxvkrtnmpshdfgj"
const ARROWS = "^><"

const SYLLABLES = [
    "na", "zu", "na",
    "mi", "sa", "to",
    "an", "ko",
    "en", "gage",
    "tu", "dy",
    "go", "jo",
    "cal", "co"
]

const BASE85 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~"


static func encode(message: String, language: Language) -> String:
    var data := message.to_utf8_buffer()

    match language:
        Language.CONSONANT:
            return _consonant(data)
        Language.SYLLABLE:
            return _syllable(data)
        Language.NUMERIC:
            return _numeric(data)
        Language.STATIC:
            return _static(data)
        Language.ARROWS:
            return _arrows(data)
    
    return message


static func _group(text: String, size: int) -> String:
    var groups := PackedStringArray()
    for i in range(0, text.length(), size):
        groups.append(text.substr(i, size))
    return " ".join(groups)


# CONSONANT LANGUAGE (1 byte becomes 2 consonants)
static func _consonant(data: PackedByteArray) -> String:
    var result := ""
    for b in data:
        result += CONSONANTS.substr(b >> 4, 1)
        result += CONSONANTS.substr(b & 15, 1)
    return _group(result, 12)


# SYLLABLE LANGUAGE (1 byte becomes 2 syllable)
static func _syllable(data: PackedByteArray) -> String:
    var result := ""
    for b in data:
        result += SYLLABLES[b >> 4]
        result += SYLLABLES[b & 15]
    return _group(result, 12)


# NUMERIC LANGUAGE
# Each byte becomes a three-digit number.
static func _numeric(data: PackedByteArray) -> String:
    var result := PackedStringArray()
    for b in data:
        result.append("%03d" % b)
    return "-".join(result)


# STATIC LANGUAGE (Base85, no scrambling)
static func _static(data: PackedByteArray) -> String:
    var result := ""
    for start in range(0, data.size(), 4):
        var count := mini(4, data.size() - start)
        var value: int = 0
        for i in range(4):
            value <<= 8
            if i < count:
                value |= data[start + i]
        var encoded := ""
        for i in range(5):
            encoded = BASE85.substr(value % 85, 1) + encoded
            value = int(value / 85)
        if count < 4:
            encoded = encoded.substr(0, count + 1)
        result += encoded
    return result


# ARROW LANGUAGE (1 byte becomes three symbols: ^ > <)
static func _arrows(data: PackedByteArray) -> String:
    var result := ""
    for b in data:
        var n: int = b % 27
        result += ARROWS.substr(int(n / 9), 1)
        result += ARROWS.substr(int(n / 3) % 3, 1)
        result += ARROWS.substr(n % 3, 1)
    return result
