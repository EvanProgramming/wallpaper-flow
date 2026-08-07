import Foundation

// MARK: - Performance Mode

public enum PerformanceMode: String, CaseIterable, Codable, Sendable {
    case automatic
    case quality
    case balanced
    case batterySaver
    
    public var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .quality: return "Quality"
        case .balanced: return "Balanced"
        case .batterySaver: return "Battery Saver"
        }
    }
    
    public var targetFPS: Int {
        switch self {
        case .automatic: return 60
        case .quality: return 60
        case .balanced: return 30
        case .batterySaver: return 24
        }
    }
    
    public var maxFPS: Int {
        switch self {
        case .automatic: return 120
        case .quality: return 120
        case .balanced: return 60
        case .batterySaver: return 30
        }
    }
    
    public var reduceParticles: Bool {
        switch self {
        case .automatic, .quality: return false
        case .balanced: return true
        case .batterySaver: return true
        }
    }
    
    public var reduceBlur: Bool {
        switch self {
        case .automatic, .quality: return false
        case .balanced: return false
        case .batterySaver: return true
        }
    }
}