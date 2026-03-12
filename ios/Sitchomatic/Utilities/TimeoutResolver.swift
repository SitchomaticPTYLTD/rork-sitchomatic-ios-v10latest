import Foundation

@MainActor
enum TimeoutResolver {
    static var shared: AutomationSettings {
        if let data = UserDefaults.standard.data(forKey: "automation_settings_v1"),
           let loaded = try? JSONDecoder().decode(AutomationSettings.self, from: data) {
            return loaded
        }
        return AutomationSettings()
    }

    static var userTestTimeout: TimeInterval {
        if let data = UserDefaults.standard.data(forKey: "login_settings_v2"),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let t = dict["testTimeout"] as? TimeInterval {
            return t
        }
        return 90
    }

    static func resolveRequestTimeout(_ hardcoded: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        if pageLoad > 0 {
            return pageLoad
        }
        return hardcoded
    }

    static func resolveResourceTimeout(_ hardcoded: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        if pageLoad > 0 {
            return pageLoad + 30
        }
        return hardcoded + 30
    }

    static func resolvePageLoadTimeout(_ hardcoded: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        if pageLoad > 0 {
            return pageLoad
        }
        return hardcoded
    }

    static func resolveHeartbeatTimeout(_ hardcoded: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        let effective = pageLoad > 0 ? pageLoad : hardcoded
        return effective + 30
    }

    static func resolveTestTimeout(_ hardcoded: TimeInterval, userSetting: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        if userSetting > 0 && userSetting != 90 {
            return userSetting
        }
        if pageLoad > 0 {
            return max(hardcoded, pageLoad)
        }
        return hardcoded
    }

    static func resolveAutoHealCap(_ currentTimeout: TimeInterval) -> TimeInterval {
        let pageLoad = shared.pageLoadTimeout
        if pageLoad > 0 {
            return max(currentTimeout, pageLoad)
        }
        return currentTimeout
    }
}
