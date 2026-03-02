import Cocoa

class PRMenuItemView: NSView {
    
    private static let menuItemHeight: CGFloat = 22
    private static let minimumMenuWidth: CGFloat = 360
    
    private let leftMargin: CGFloat = 20
    private let rightMargin: CGFloat = 12
    private let horizontalSpacing: CGFloat = 8
    private let iconWidth: CGFloat = 16
    
    private lazy var statusIcon: NSImageView = {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentTintColor = NSColor.secondaryLabelColor
        return imageView
    }()
    
    private lazy var statusLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = NSFont.menuFont(ofSize: 0)
        field.alignment = .center
        field.setContentHuggingPriority(.required, for: .horizontal)
        return field
    }()
    
    private lazy var titleLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.translatesAutoresizingMaskIntoConstraints = false
        field.lineBreakMode = .byTruncatingTail
        field.font = NSFont.menuFont(ofSize: 0)
        field.textColor = NSColor.controlTextColor
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }()
    
    private lazy var repoLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = NSFont.menuFont(ofSize: 0)
        field.textColor = NSColor.secondaryLabelColor
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }()
    
    private lazy var timeLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = NSFont.menuFont(ofSize: 0)
        field.textColor = NSColor.tertiaryLabelColor
        field.alignment = .right
        field.setContentHuggingPriority(.required, for: .horizontal)
        return field
    }()
    
    private lazy var highlightView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.state = .active
        view.material = .selection
        view.blendingMode = .behindWindow
        view.isEmphasized = true
        view.wantsLayer = true
        view.isHidden = true
        return view
    }()
    
    private var currentStatus: String = "none"
    private var currentIsDraft: Bool = false

    private static let pendingStatusImage: NSImage? = {
        if let image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Checks pending") {
            return image
        }
        return NSImage(systemSymbolName: "clock", accessibilityDescription: "Checks pending")
    }()
    
    init(title: String, repo: String, time: String, status: String, isDraft: Bool) {
        let frame = NSRect(x: 0, y: 0, width: Self.minimumMenuWidth, height: Self.menuItemHeight)
        super.init(frame: frame)
        
        currentStatus = status
        currentIsDraft = isDraft
        
        setupView()
        configure(title: title, repo: repo, time: time, status: status, isDraft: isDraft)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        
        addSubview(highlightView)
        NSLayoutConstraint.activate([
            highlightView.topAnchor.constraint(equalTo: topAnchor),
            highlightView.leadingAnchor.constraint(equalTo: leadingAnchor),
            highlightView.bottomAnchor.constraint(equalTo: bottomAnchor),
            highlightView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        addSubview(timeLabel)
        NSLayoutConstraint.activate([
            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -rightMargin),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        addSubview(statusIcon)
        addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leftMargin),
            statusIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: iconWidth),
            statusIcon.heightAnchor.constraint(equalToConstant: iconWidth),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leftMargin),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: iconWidth)
        ])
        
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leftMargin + iconWidth + horizontalSpacing),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -horizontalSpacing)
        ])
    }
    
    func configure(title: String, repo: String, time: String, status: String, isDraft: Bool) {
        titleLabel.stringValue = title
        timeLabel.stringValue = time
        currentStatus = status
        currentIsDraft = isDraft
        
        updateStatusDisplay()
    }
    
    private func updateStatusDisplay() {
        switch currentStatus {
        case "review_changes_requested":
            statusLabel.stringValue = "✓"
            statusLabel.textColor = NSColor.systemGreen
            statusLabel.isHidden = false
            statusIcon.isHidden = true
        case "review_approved":
            statusLabel.stringValue = "✓"
            statusLabel.textColor = NSColor.systemGreen
            statusLabel.isHidden = false
            statusIcon.isHidden = true
        case "success":
            statusLabel.stringValue = "✓"
            statusLabel.textColor = NSColor.systemGreen
            statusLabel.isHidden = false
            statusIcon.isHidden = true
        case "failure":
            statusLabel.stringValue = "⊗"
            statusLabel.textColor = NSColor.systemRed
            statusLabel.isHidden = false
            statusIcon.isHidden = true
        case "pending":
            statusLabel.isHidden = true
            statusIcon.isHidden = false
            statusIcon.image = Self.pendingStatusImage
            statusIcon.contentTintColor = NSColor.systemOrange
        default:
            statusLabel.isHidden = true
            statusIcon.isHidden = false
            let imageName = currentIsDraft ? "pull-request-draft" : "pull-request-open"
            statusIcon.image = NSImage(named: imageName)
            statusIcon.contentTintColor = NSColor.secondaryLabelColor
        }
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: max(frame.width, Self.minimumMenuWidth), height: Self.menuItemHeight)
    }
    
    override func layout() {
        super.layout()
        syncToContainerWidth()
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let isHighlighted = enclosingMenuItem?.isHighlighted ?? false
        let isEnabled = enclosingMenuItem?.isEnabled ?? true
        
        highlightView.isHidden = !isHighlighted
        
        if isHighlighted {
            titleLabel.textColor = NSColor.selectedMenuItemTextColor
            timeLabel.textColor = NSColor.selectedMenuItemTextColor
            statusLabel.textColor = NSColor.selectedMenuItemTextColor
            statusIcon.contentTintColor = NSColor.selectedMenuItemTextColor
        } else if isEnabled {
            titleLabel.textColor = NSColor.controlTextColor
            timeLabel.textColor = NSColor.tertiaryLabelColor
            updateStatusDisplay()
        } else {
            titleLabel.textColor = NSColor.disabledControlTextColor
            timeLabel.textColor = NSColor.disabledControlTextColor
            statusLabel.textColor = NSColor.disabledControlTextColor
            statusIcon.contentTintColor = NSColor.disabledControlTextColor
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        syncToContainerWidth()
        updateTrackingAreas()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        syncToContainerWidth()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseDown(with event: NSEvent) {
        if let menuItem = enclosingMenuItem {
            _ = menuItem.target?.perform(menuItem.action, with: menuItem)
        }
    }

    private func syncToContainerWidth() {
        guard let container = superview else { return }
        let width = container.bounds.width
        guard width > 0 else { return }
        if abs(frame.width - width) > 0.5 {
            frame = NSRect(x: 0, y: 0, width: width, height: Self.menuItemHeight)
            invalidateIntrinsicContentSize()
        }
    }
    
    override var allowsVibrancy: Bool { false }
}
