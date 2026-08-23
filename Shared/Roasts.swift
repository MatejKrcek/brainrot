import Foundation

/// Offline coach lines, used when no API key is set or the request fails.
enum Roasts {
    static func line(for snap: RotSnapshot, language: String) -> String {
        let cs = language == "cs"
        switch snap.stage {
        case .fresh:
            return cs ? "Mozek křupe jak čerstvý rohlík. Dnes \(snap.minutes.asDuration) scrollu — drž to tak, nebo ti to během hodiny zkysne."
                      : "Brain's crisp as a fresh baguette. \(snap.minutes.asDuration) of scrolling today — keep it there or it curdles by dinner."
        case .mushy:
            return cs ? "Už to měkne. \(snap.minutes.asDuration) z \(snap.limit.asDuration). Každý další Reel je lžička jogurtu navíc do lebky."
                      : "Getting mushy. \(snap.minutes.asDuration) of \(snap.limit.asDuration). Every extra Reel is another spoonful of yogurt in the skull."
        case .rotting:
            return cs ? "Hnije to. \(snap.rotPercent) %. Tohle není relax, tohle je kompost. Zvedni se, dej si vodu, dýchej."
                      : "It's rotting. \(snap.rotPercent)%. This isn't rest, it's compost. Stand up, drink water, breathe."
        case .decayed:
            return cs ? "\(snap.rotPercent) % rozkladu. Ještě \(snap.minutesLeft.asDuration) a jsi tekutina. Telefon na stůl, obrazovkou dolů."
                      : "\(snap.rotPercent)% decayed. \(snap.minutesLeft.asDuration) to full liquid. Phone on the table, face down."
        case .liquefied:
            return cs ? "Tekutý stav. \(snap.minutes.asDuration) dnes. Mozek by se dal vypít brčkem. Zítra nový den — nebo ne, jak chceš."
                      : "Liquefied. \(snap.minutes.asDuration) today. You could drink this brain with a straw. Tomorrow's a new day — or not, up to you."
        }
    }

    static func shieldSubtitle(for snap: RotSnapshot) -> String {
        "Brain is \(snap.rotPercent)% rotten · \(snap.minutes.asDuration) today. Open Brainrot and earn \(SharedStore.unlockMinutes) min."
    }
}
