import Cocoa
import os.log

private final class PRMenuPayload: NSObject {
    let htmlUrl: String
    let prId: String?
    let updatedAt: String?
    
    init(htmlUrl: String, prId: String? = nil, updatedAt: String? = nil) {
        self.htmlUrl = htmlUrl
        self.prId = prId
        self.updatedAt = updatedAt
    }
}

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var core: GitHubTrayCore!
    private var currentState: AppState?
    private var eventHandler: GitHubTrayEventHandler!
    private let logger = OSLog(subsystem: "com.github-tray.app", category: "StatusBarController")
    private let ignoredReviewRequestsDefaultsKey = "ignoredReviewRequestsById"
    private var ignoredReviewRequestsById: [String: String] = [:]
    
    private let menuBarIcon: NSImage = {
        guard let image = NSImage(named: "menuTemplate") else {
            fatalError("Failed to load menuTemplate image")
        }
        image.isTemplate = true
        image.size = NSSize(width: 22, height: 22)
        return image
    }()
    
    override init() {
        super.init()
        os_log("StatusBarController init started", log: logger, type: .info)
        ignoredReviewRequestsById = loadIgnoredReviewRequests()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = menuBarIcon
        statusItem.button?.imagePosition = .imageLeading
        os_log("Status bar item created", log: logger, type: .info)
        
        eventHandler = GitHubTrayEventHandler(controller: self)
        os_log("Event handler created", log: logger, type: .info)
        
        os_log("Initializing Rust core...", log: logger, type: .info)
        do {
            core = try GitHubTrayCore(eventHandler: eventHandler)
            os_log("Rust core initialized successfully", log: logger, type: .info)
        } catch {
            os_log("Failed to initialize Rust core: %{public}@", log: logger, type: .error, error.localizedDescription)
            showError("Failed to initialize: \(error.localizedDescription)")
            return
        }
        
        rebuildMenu()
        os_log("Initial menu built", log: logger, type: .info)
        
        os_log("StatusBarController init completed", log: logger, type: .info)
    }
    
    func updateState(_ state: AppState) {
        os_log(
            "updateState called with %d review, %d my PRs, %d mentioned",
            log: logger,
            type: .info,
            state.reviewCount,
            state.myPrCount,
            state.mentionedCount
        )
        reconcileIgnoredReviewRequests(with: state.prs.reviewRequested)
        currentState = state
        updateMenuBar()
        rebuildMenu()
    }
    
    func showError(_ message: String) {
        os_log("Showing error: %{public}@", log: logger, type: .error, message)
        statusItem.button?.image = menuBarIcon
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = "!"
        statusItem.button?.toolTip = "GitHub Tray - Error: \(message)"
        
        let menu = NSMenu()
        menu.addItem(withTitle: "Error", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: message, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(createMenuItem("Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    private func updateMenuBar() {
        guard let state = currentState else {
            statusItem.button?.image = menuBarIcon
            statusItem.button?.imagePosition = .imageLeading
            statusItem.button?.title = ""
            return
        }
        
        statusItem.button?.image = menuBarIcon
        statusItem.button?.imagePosition = .imageLeading
        
        if state.isLoading {
            statusItem.button?.title = "..."
        } else if let error = state.errorMessage {
            statusItem.button?.title = "!"
            statusItem.button?.toolTip = "GitHub Tray - Error: \(error)"
            return
        } else {
            let visibleReviewCount = visibleReviewRequestedPRs(for: state).count
            if visibleReviewCount > 0 {
                statusItem.button?.title = "\(visibleReviewCount)"
            } else {
                statusItem.button?.title = ""
            }
        }
        
        let visibleReviewCount = visibleReviewRequestedPRs(for: state).count
        statusItem.button?.toolTip = "GitHub Tray - \(visibleReviewCount) review requested, \(state.myPrCount) my PRs, \(state.mentionedCount) mentioned"
        os_log("Menu bar title updated to: %{public}@", log: logger, type: .info, statusItem.button?.title ?? "nil")
    }
    
    private func rebuildMenu() {
        let menu = NSMenu()
        
        guard let state = currentState else {
            menu.addItem(withTitle: "Loading...", action: nil, keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(createMenuItem("Quit", action: #selector(quit), keyEquivalent: "q"))
            statusItem.menu = menu
            return
        }

        let approvedMyOpen = state.prs.myOpen.filter { $0.reviewBucket == "approved" }
        let returnedToYouMyOpen = state.prs.myOpen.filter { $0.reviewBucket == "returned_to_you" }
        let generalMyOpen = state.prs.myOpen.filter {
            $0.reviewBucket != "approved" && $0.reviewBucket != "returned_to_you"
        }
        let visibleReviewRequested = visibleReviewRequestedPRs(for: state)
        
        // Review Requested section
        if !visibleReviewRequested.isEmpty {
            menu.addItem(createHeader("Review Requested (\(visibleReviewRequested.count))"))
            for pr in visibleReviewRequested {
                menu.addItem(createReviewRequestedPRItem(pr))
            }
            menu.addItem(.separator())
        }
        
        // Approved section
        if !approvedMyOpen.isEmpty {
            menu.addItem(createHeader("Approved (\(approvedMyOpen.count))"))
            for pr in approvedMyOpen {
                menu.addItem(createPRItem(pr))
            }
            menu.addItem(.separator())
        }

        // Returned to You section
        if !returnedToYouMyOpen.isEmpty {
            menu.addItem(createHeader("Returned to You (\(returnedToYouMyOpen.count))"))
            for pr in returnedToYouMyOpen {
                menu.addItem(createPRItem(pr))
            }
            menu.addItem(.separator())
        }

        // My Open PRs section
        if !generalMyOpen.isEmpty {
            menu.addItem(createHeader("My Open PRs (\(generalMyOpen.count))"))
            for pr in generalMyOpen {
                menu.addItem(createPRItem(pr))
            }
            menu.addItem(.separator())
        }
        
        // Mentioned In section
        if !state.prs.mentionedIn.isEmpty {
            menu.addItem(createHeader("Mentioned In (\(state.prs.mentionedIn.count))"))
            for pr in state.prs.mentionedIn {
                menu.addItem(createPRItem(pr))
            }
            menu.addItem(.separator())
        }
        
        // No PRs message
        if visibleReviewRequested.isEmpty
            && approvedMyOpen.isEmpty
            && returnedToYouMyOpen.isEmpty
            && generalMyOpen.isEmpty
            && state.prs.mentionedIn.isEmpty
        {
            let item = menu.addItem(withTitle: "No pull requests", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(.separator())
        }
        
        // Controls
        menu.addItem(createMenuItem("Refresh", action: #selector(refresh), keyEquivalent: "r"))
        menu.addItem(createAutostartItem(state.autostartEnabled))
        menu.addItem(.separator())
        menu.addItem(createMenuItem("Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func createMenuItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }
    
    private func createHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
    
    private func createPRItem(_ pr: PullRequest) -> NSMenuItem {
        let item = NSMenuItem(title: pr.title, action: #selector(openPR(_:)), keyEquivalent: "")
        item.target = self
        
        let view = PRMenuItemView(title: pr.title, repo: pr.repository, time: pr.displayTime, status: pr.status, isDraft: pr.isDraft)
        item.view = view
        item.representedObject = PRMenuPayload(htmlUrl: pr.htmlUrl)
        
        return item
    }

    private func createReviewRequestedPRItem(_ pr: PullRequest) -> NSMenuItem {
        let item = NSMenuItem(title: "\(pr.title) · \(pr.repository) · \(pr.displayTime)", action: nil, keyEquivalent: "")
        let payload = PRMenuPayload(htmlUrl: pr.htmlUrl, prId: pr.id, updatedAt: pr.updatedAt)

        let submenu = NSMenu(title: pr.title)
        let openItem = NSMenuItem(title: "Open", action: #selector(openPR(_:)), keyEquivalent: "")
        openItem.target = self
        openItem.representedObject = payload
        submenu.addItem(openItem)

        let ignoreItem = NSMenuItem(title: "Ignore", action: #selector(ignoreReviewRequestedPR(_:)), keyEquivalent: "")
        ignoreItem.target = self
        ignoreItem.representedObject = payload
        submenu.addItem(ignoreItem)

        item.submenu = submenu
        return item
    }
    
    private func createAutostartItem(_ enabled: Bool) -> NSMenuItem {
        let title = enabled ? "✓ Autostart" : "Autostart"
        let item = NSMenuItem(title: title, action: #selector(toggleAutostart), keyEquivalent: "")
        item.target = self
        return item
    }
    
    // MARK: - Actions
    
    @objc func refresh() {
        os_log("Refresh triggered", log: logger, type: .info)
        refreshAsync()
    }
    
    private func refreshAsync() {
        Task { @MainActor in
            do {
                try core.refresh()
            } catch {
                showError("Failed to refresh: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func openPR(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? PRMenuPayload else { return }
        os_log("Open PR: %{public}@", log: logger, type: .info, payload.htmlUrl)
        
        statusItem.menu?.cancelTracking()
        
        guard let url = URL(string: payload.htmlUrl) else {
            showError("Invalid PR URL")
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc func ignoreReviewRequestedPR(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? PRMenuPayload else { return }
        guard let prId = payload.prId, let updatedAt = payload.updatedAt else { return }
        os_log("Ignore review requested PR: %{public}@", log: logger, type: .info, prId)

        ignoredReviewRequestsById[prId] = updatedAt
        saveIgnoredReviewRequests()
        updateMenuBar()
        rebuildMenu()
    }
    
    @objc func toggleAutostart() {
        os_log("Toggle autostart", log: logger, type: .info)
        do {
            _ = try core.toggleAutostart()
        } catch {
            showError("Failed to toggle autostart: \(error.localizedDescription)")
        }
    }
    
    @objc func quit() {
        os_log("Quit requested", log: logger, type: .info)
        NSApp.terminate(nil)
    }

    private func visibleReviewRequestedPRs(for state: AppState) -> [PullRequest] {
        return state.prs.reviewRequested.filter { pr in
            guard let ignoredUpdatedAt = ignoredReviewRequestsById[pr.id] else {
                return true
            }
            return ignoredUpdatedAt != pr.updatedAt
        }
    }

    private func reconcileIgnoredReviewRequests(with reviewRequested: [PullRequest]) {
        guard !ignoredReviewRequestsById.isEmpty else { return }

        let currentById = Dictionary(uniqueKeysWithValues: reviewRequested.map { ($0.id, $0.updatedAt) })
        var changed = false

        for (id, ignoredUpdatedAt) in ignoredReviewRequestsById {
            guard let currentUpdatedAt = currentById[id] else {
                ignoredReviewRequestsById.removeValue(forKey: id)
                changed = true
                continue
            }

            if currentUpdatedAt != ignoredUpdatedAt {
                ignoredReviewRequestsById.removeValue(forKey: id)
                changed = true
            }
        }

        if changed {
            saveIgnoredReviewRequests()
        }
    }

    private func loadIgnoredReviewRequests() -> [String: String] {
        guard let value = UserDefaults.standard.dictionary(forKey: ignoredReviewRequestsDefaultsKey) as? [String: String] else {
            return [:]
        }
        return value
    }

    private func saveIgnoredReviewRequests() {
        UserDefaults.standard.set(ignoredReviewRequestsById, forKey: ignoredReviewRequestsDefaultsKey)
    }
}
