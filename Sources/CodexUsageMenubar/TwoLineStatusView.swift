import AppKit

final class TwoLineStatusView: NSView {
    private let firstLine = NSTextField(labelWithString: "ChatGPT --")
    private let secondLine = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(lines: [String]) {
        firstLine.stringValue = lines.indices.contains(0) ? lines[0] : ""
        secondLine.stringValue = lines.indices.contains(1) ? lines[1] : ""
        needsLayout = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func setup() {
        wantsLayer = true
        for label in [firstLine, secondLine] {
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            label.textColor = .labelColor
            label.alignment = .left
            label.lineBreakMode = .byClipping
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }

        NSLayoutConstraint.activate([
            firstLine.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            firstLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            firstLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            secondLine.topAnchor.constraint(equalTo: firstLine.bottomAnchor, constant: -1),
            secondLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            secondLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            secondLine.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -1)
        ])
    }
}
