//
//  MoyeoTheme.swift
//  MoyeoTrip
//

import SwiftUI
import UIKit

enum MoyeoTheme {
    static let forest = Color(hex: "#2D8F5A")
    static let coral = Color(hex: "#FF7550")
    static let leaf = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#07110E") : UIColor(hex: "#F0F8F4")
    })
    static let mint = Color(hex: "#BFE9D2")
    static let river = Color(hex: "#3E9BCF")
    static let blossom = Color(hex: "#F2A7B8")
    static let sunrise = Color(hex: "#F8B84E")
    static let ink = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#F4F8F5") : UIColor(hex: "#0F1714")
    })
    static let text700 = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#D8E2DC") : UIColor(hex: "#2F3A35")
    })
    static let muted = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#A7B6AE") : UIColor(hex: "#5A6761")
    })
    static let text400 = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#7D8D85") : UIColor(hex: "#8A948E")
    })
    static let line = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#34453D") : UIColor(hex: "#D9DDD9")
    })
    static let softLine = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#24332D") : UIColor(hex: "#EEF0EE")
    })
    static let background = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#0D1411") : UIColor(hex: "#FFFFFF")
    })
    static let subtleBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#141D19") : UIColor(hex: "#F7F8F7")
    })
    static let card = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#18231E") : UIColor(hex: "#FFFFFF")
    })
    static let elevatedCard = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#1F2B25") : UIColor(hex: "#FFFFFF")
    })
    static let mapGreen = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#263B31") : UIColor(hex: "#E4F0E7")
    })
    static let mapWater = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#203946") : UIColor(hex: "#CFE2EA")
    })

    static let cardRadius: CGFloat = 9
}

enum MoyeoTypography {
    static let screenTitle = Font.system(size: 21, weight: .heavy)
    static let sectionTitle = Font.system(size: 18, weight: .heavy)
    static let tab = Font.system(size: 15, weight: .heavy)
    static let cardTitle = Font.system(size: 17, weight: .heavy)
    static let cardBody = Font.system(size: 14, weight: .semibold)
    static let cardMeta = Font.system(size: 13, weight: .semibold)
    static let chip = Font.system(size: 12, weight: .heavy)
    static let tinyMeta = Font.system(size: 11, weight: .semibold)
}

extension WeatherHeroState {
    var cardColor: Color {
        switch self {
        case .good:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(hex: "#174C37") : UIColor(hex: "#2D8F5A")
            })
        case .caution:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(hex: "#65411B") : UIColor(hex: "#B87726")
            })
        case .blocked:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(hex: "#243E43") : UIColor(hex: "#355D5C")
            })
        }
    }

    var selectedPillBackground: Color {
        switch self {
        case .good:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(hex: "#07110E").withAlphaComponent(0.78) : .white.withAlphaComponent(0.92)
            })
        case .caution:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(hex: "#261A0B").withAlphaComponent(0.82) : UIColor(hex: "#FFF7E8")
            })
        case .blocked:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(hex: "#081618").withAlphaComponent(0.82) : UIColor(hex: "#EEF6F4")
            })
        }
    }

    var selectedPillForeground: Color {
        switch self {
        case .good:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(hex: "#DCEFE3") : UIColor(hex: "#155735")
            })
        case .caution:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(hex: "#FFE3B2") : UIColor(hex: "#87530D")
            })
        case .blocked:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(hex: "#D7EFEB") : UIColor(hex: "#254C4B")
            })
        }
    }
}

extension CourseMood {
    var accent: Color {
        switch self {
        case .forest:
            return MoyeoTheme.forest
        case .coral:
            return MoyeoTheme.coral
        case .river:
            return MoyeoTheme.river
        case .blossom:
            return MoyeoTheme.blossom
        case .sunrise:
            return MoyeoTheme.sunrise
        }
    }

    var softBackground: Color {
        accent.opacity(0.14)
    }

    var landscapeSkyColors: [Color] {
        switch self {
        case .forest:
            return [adaptiveColor(light: "#DCE9DD", dark: "#2A3D32"), adaptiveColor(light: "#ADC6AE", dark: "#17271F")]
        case .coral:
            return [adaptiveColor(light: "#E7D4BF", dark: "#382E29"), adaptiveColor(light: "#B98968", dark: "#211914")]
        case .river:
            return [adaptiveColor(light: "#D7E4E8", dark: "#263843"), adaptiveColor(light: "#9BB8BF", dark: "#14232B")]
        case .blossom:
            return [adaptiveColor(light: "#E8D8DB", dark: "#383036"), adaptiveColor(light: "#B99FA6", dark: "#221A20")]
        case .sunrise:
            return [adaptiveColor(light: "#E9D7B8", dark: "#3A3125"), adaptiveColor(light: "#BDA06E", dark: "#211A12")]
        }
    }

    var landscapeBackMountain: Color {
        switch self {
        case .forest:
            return adaptiveColor(light: "#769273", dark: "#2D4436")
        case .coral:
            return adaptiveColor(light: "#9E7459", dark: "#4A3528")
        case .river:
            return adaptiveColor(light: "#6F8D96", dark: "#2D4652")
        case .blossom:
            return adaptiveColor(light: "#967F86", dark: "#47343D")
        case .sunrise:
            return adaptiveColor(light: "#9B815B", dark: "#46371F")
        }
    }

    var landscapeFrontMountain: Color {
        switch self {
        case .forest:
            return adaptiveColor(light: "#435C48", dark: "#182B21")
        case .coral:
            return adaptiveColor(light: "#604737", dark: "#291F19")
        case .river:
            return adaptiveColor(light: "#405966", dark: "#172C35")
        case .blossom:
            return adaptiveColor(light: "#5E4D55", dark: "#271F25")
        case .sunrise:
            return adaptiveColor(light: "#5E4D38", dark: "#271F14")
        }
    }

    var landscapeGround: Color {
        switch self {
        case .forest:
            return adaptiveColor(light: "#243D2F", dark: "#0B1812")
        case .coral:
            return adaptiveColor(light: "#382E29", dark: "#120E0C")
        case .river:
            return adaptiveColor(light: "#233A45", dark: "#0B161C")
        case .blossom:
            return adaptiveColor(light: "#3B3038", dark: "#130F12")
        case .sunrise:
            return adaptiveColor(light: "#3D3428", dark: "#151009")
        }
    }
}

func adaptiveColor(light: String, dark: String) -> Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    })
}

extension RecruitmentStatus {
    var tint: Color {
        switch self {
        case .open:
            return MoyeoTheme.forest
        case .almostFull:
            return MoyeoTheme.coral
        case .confirmed:
            return MoyeoTheme.river
        case .cancelled:
            return MoyeoTheme.muted
        }
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch sanitized.count {
        case 3:
            red = ((value >> 8) & 0xF) * 17
            green = ((value >> 4) & 0xF) * 17
            blue = (value & 0xF) * 17
            alpha = 255
        case 6:
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
            alpha = 255
        case 8:
            red = (value >> 24) & 0xFF
            green = (value >> 16) & 0xFF
            blue = (value >> 8) & 0xFF
            alpha = value & 0xFF
        default:
            red = 45
            green = 143
            blue = 90
            alpha = 255
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension View {
    func moyeoCard() -> some View {
        padding(16)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(MoyeoTheme.line, lineWidth: 1)
            }
            .shadow(color: MoyeoTheme.ink.opacity(0.02), radius: 6, x: 0, y: 3)
    }
}
