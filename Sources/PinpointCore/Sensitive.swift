import Foundation
import CoreGraphics

public enum SensitiveKind: String, Codable, CaseIterable, Sendable {
    case email, apiKey, accountID, phone, creditCard, ipAddress, ssn, custom, face

    public var label: String {
        switch self {
        case .email: return "Email"
        case .apiKey: return "API key / secret"
        case .accountID: return "Account / ad ID"
        case .custom: return "Your redact word"
        case .phone: return "Phone number"
        case .creditCard: return "Card number"
        case .ipAddress: return "IP address"
        case .ssn: return "SSN"
        case .face: return "Face"
        }
    }
}

public struct SensitiveRegion: Codable, Equatable, Sendable {
    public var kind: SensitiveKind
    public var text: String?
    public var rect: CGRect   // image pixels, top-left origin
    public init(kind: SensitiveKind, text: String?, rect: CGRect) { self.kind = kind; self.text = text; self.rect = rect }
}

public struct TextMatch: Equatable {
    public var kind: SensitiveKind
    public var range: Range<String.Index>
    public var value: String
}

/// Finds secrets/PII in plain text. Pure and fast; runs on OCR output.
public enum SensitiveDetector {
    static let patterns: [(SensitiveKind, NSRegularExpression)] = {
        func re(_ p: String, _ opts: NSRegularExpression.Options = []) -> NSRegularExpression { try! NSRegularExpression(pattern: p, options: opts) }
        return [
            (.email, re(#"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#, .caseInsensitive)),
            (.apiKey, re(#"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#)),
            (.apiKey, re(#"\bgh[pousr]_[A-Za-z0-9]{30,}\b"#)),
            (.apiKey, re(#"\bxox[abprs]-[A-Za-z0-9\-]{10,}"#)),
            (.apiKey, re(#"\bAIza[0-9A-Za-z_\-]{30,}"#)),
            (.apiKey, re(#"\b(?:sk|pk|rk)[-_](?:live[-_]|test[-_]|proj[-_]|ant[-_])?[A-Za-z0-9_\-]{16,}"#)),
            (.apiKey, re(#"\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}"#)),
            (.apiKey, re(#"(?i)(?:api[_\- ]?key|secret|token|password|passwd)\s*[:=]\s*\S{6,}"#)),
            (.apiKey, re(#"\bEAA[A-Za-z0-9]{20,}"#)),                                   // Meta / Facebook access token
            (.apiKey, re(#"\bya29\.[A-Za-z0-9_\-]{20,}"#)),                            // Google OAuth access token
            (.apiKey, re(#"\bshp(?:at|ca|pa|ss)_[A-Fa-f0-9]{20,}"#)),                   // Shopify tokens
            (.accountID, re(#"(?i)\bact_\d{6,20}\b"#)),                                 // Meta ad account
            (.accountID, re(#"\b(?:acct|cus|sub|pi|pm|ch|in|prod|price|seti|cs)_[A-Za-z0-9]{10,}\b"#)), // Stripe IDs
            (.accountID, re(#"\bG-[A-Z0-9]{6,12}\b"#)),                                 // GA4 measurement ID
            (.accountID, re(#"\bUA-\d{4,12}-\d{1,4}\b"#)),                             // Universal Analytics
            (.accountID, re(#"\bGTM-[A-Z0-9]{4,9}\b"#)),                                // Google Tag Manager
            (.accountID, re(#"\bAW-\d{6,12}\b"#)),                                     // Google Ads conversion ID
            (.accountID, re(#"(?i)(?:customer|account|ads?)\s*(?:id|#)?\s*[:#]?\s*\d{3}-\d{3}-\d{4}\b"#)), // Google Ads customer ID
            (.creditCard, re(#"\b(?:\d[ \-]?){13,19}\b"#)),
            (.ssn, re(#"\b\d{3}-\d{2}-\d{4}\b"#)),
            (.phone, re(#"(?:\+?\d{1,3}[ .\-]?)?\(?\d{3}\)?[ .\-]\d{3}[ .\-]\d{4}\b"#)),
            (.ipAddress, re(#"\b(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)\b"#)),
            (.accountID, re(#"\b\d{15,19}\b"#)),   // long numeric IDs (Meta pixel/page/ad IDs…); real card numbers are caught first
        ]
    }()

    public static func findMatches(in text: String, customTerms: [String] = []) -> [TextMatch] {
        var out: [TextMatch] = []
        let ns = NSRange(text.startIndex..., in: text)
        // The user's own "always redact" words first (case-insensitive, whole text match anywhere).
        for term in customTerms.map({ $0.trimmingCharacters(in: .whitespaces) }) where term.count >= 2 {
            var from = text.startIndex
            while let r = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: from..<text.endIndex) {
                out.append(TextMatch(kind: .custom, range: r, value: String(text[r])))
                from = r.upperBound
            }
        }
        for (kind, regex) in patterns {
            for m in regex.matches(in: text, range: ns) {
                guard let r = Range(m.range, in: text) else { continue }
                let value = String(text[r])
                if kind == .creditCard && !luhnValid(value) { continue }
                // Skip anything already covered by an earlier (more specific) match.
                if out.contains(where: { $0.range.overlaps(r) }) { continue }
                out.append(TextMatch(kind: kind, range: r, value: value))
            }
        }
        return out
    }

    static func luhnValid(_ s: String) -> Bool {
        let digits = s.compactMap { $0.wholeNumberValue }
        guard (13...19).contains(digits.count) else { return false }
        var sum = 0
        for (i, d) in digits.reversed().enumerated() {
            if i % 2 == 1 { let x = d * 2; sum += x > 9 ? x - 9 : x } else { sum += d }
        }
        return sum % 10 == 0
    }
}
