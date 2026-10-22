import Foundation

/// Normalisierter Stand, den die Bridge in `status.json` ablegt und die App anzeigt.
/// Die Limits gelten fürs ganze Konto, die übrigen Felder nur für die Session,
/// die zuletzt geschrieben hat.
public struct ClaudeStatusSnapshot: Codable, Equatable, Sendable {
    public var fiveHour: RateLimitWindow?
    public var sevenDay: RateLimitWindow?
    public var contextUsedPercentage: Double?
    public var sessionCostUSD: Double?
    public var modelName: String?
    public var sessionID: String?
    public var capturedAt: Date

    public init(
        fiveHour: RateLimitWindow? = nil,
        sevenDay: RateLimitWindow? = nil,
        contextUsedPercentage: Double? = nil,
        sessionCostUSD: Double? = nil,
        modelName: String? = nil,
        sessionID: String? = nil,
        capturedAt: Date
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.contextUsedPercentage = contextUsedPercentage
        self.sessionCostUSD = sessionCostUSD
        self.modelName = modelName
        self.sessionID = sessionID
        self.capturedAt = capturedAt
    }

    /// Baut einen Snapshot aus dem JSON, das Claude Code an das Statuszeilen-Script übergibt.
    /// Fehlende oder unerwartete Felder werden ignoriert; nur ungültiges JSON wirft.
    public init(statusLineJSON data: Data, capturedAt: Date = Date()) throws {
        let input = try JSONDecoder().decode(StatusLineInput.self, from: data)
        self.init(
            fiveHour: input.rateLimits?.fiveHour?.window,
            sevenDay: input.rateLimits?.sevenDay?.window,
            contextUsedPercentage: input.contextWindow?.usedPercentage,
            sessionCostUSD: input.cost?.totalCostUSD,
            modelName: input.model?.displayName ?? input.model?.id,
            sessionID: input.sessionID,
            capturedAt: capturedAt
        )
    }

    /// Übernimmt Limits aus einem früheren Snapshot, wo der neue keine oder ältere hat.
    /// Wichtig, weil eine frische Session vor der ersten Antwort noch keine Limits kennt.
    public func merged(withPrevious previous: ClaudeStatusSnapshot?) -> ClaudeStatusSnapshot {
        guard let previous else { return self }
        var result = self
        result.fiveHour = RateLimitWindow.merge(fiveHour, previous.fiveHour)
        result.sevenDay = RateLimitWindow.merge(sevenDay, previous.sevenDay)
        return result
    }

    public func age(at now: Date) -> TimeInterval {
        now.timeIntervalSince(capturedAt)
    }

    public func isStale(at now: Date, threshold: TimeInterval = 30 * 60) -> Bool {
        age(at: now) > threshold
    }
}

// MARK: - Statuszeilen-Input von Claude Code

/// Ausschnitt des Statuszeilen-JSON (https://code.claude.com/docs/en/statusline).
/// Jedes Feld wird einzeln und fehlertolerant gelesen.
private struct StatusLineInput: Decodable {
    var sessionID: String?
    var model: Model?
    var cost: Cost?
    var contextWindow: ContextWindow?
    var rateLimits: RateLimits?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case model
        case cost
        case contextWindow = "context_window"
        case rateLimits = "rate_limits"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = c.lenient(String.self, forKey: .sessionID)
        model = c.lenient(Model.self, forKey: .model)
        cost = c.lenient(Cost.self, forKey: .cost)
        contextWindow = c.lenient(ContextWindow.self, forKey: .contextWindow)
        rateLimits = c.lenient(RateLimits.self, forKey: .rateLimits)
    }

    struct Model: Decodable {
        var id: String?
        var displayName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = c.lenient(String.self, forKey: .id)
            displayName = c.lenient(String.self, forKey: .displayName)
        }
    }

    struct Cost: Decodable {
        var totalCostUSD: Double?

        enum CodingKeys: String, CodingKey {
            case totalCostUSD = "total_cost_usd"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            totalCostUSD = c.lenient(Double.self, forKey: .totalCostUSD)
        }
    }

    struct ContextWindow: Decodable {
        var usedPercentage: Double?

        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            usedPercentage = c.lenient(Double.self, forKey: .usedPercentage)
        }
    }

    struct RateLimits: Decodable {
        var fiveHour: Window?
        var sevenDay: Window?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            fiveHour = c.lenient(Window.self, forKey: .fiveHour)
            sevenDay = c.lenient(Window.self, forKey: .sevenDay)
        }
    }

    struct Window: Decodable {
        var usedPercentage: Double?
        /// Unix-Sekunden
        var resetsAt: Double?

        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case resetsAt = "resets_at"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            usedPercentage = c.lenient(Double.self, forKey: .usedPercentage)
            resetsAt = c.lenient(Double.self, forKey: .resetsAt)
        }

        /// Nur vollständige Fenster sind brauchbar
        var window: RateLimitWindow? {
            guard let usedPercentage, let resetsAt else { return nil }
            return RateLimitWindow(
                usedPercentage: min(max(usedPercentage, 0), 100),
                resetsAt: Date(timeIntervalSince1970: resetsAt)
            )
        }
    }
}

private extension KeyedDecodingContainer {
    /// Liest ein Feld, liefert aber `nil` statt eines Fehlers bei falschem Typ.
    func lenient<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}
