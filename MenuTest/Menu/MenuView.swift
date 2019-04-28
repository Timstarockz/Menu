//
//  MenuView.swift
//  Menus
//
//  Created by Simeon on 2/6/18.
//  Copyright © 2018 Two Lives Left. All rights reserved.
//

import UIKit
import SnapKit

// MARK: - Variables, Enums & Initialization

public class MenuView: UIView, MenuThemeable, UIGestureRecognizerDelegate {
    
    // MARK: - Enums
    
    public enum Alignment {
        case left
        case center
        case right
    }
    
    // MARK: - Public
    
    public static let dismissMenu = Notification.Name("CodeaDissmissMenu")
    public static let menuWillPresent = Notification.Name("CodeaMenuWillPresent")
    
    public var title: String {
        didSet {
            titleLabel.text = title
            contents?.title = title
        }
    }
    
    public var contentAlignment = Alignment.right {
        didSet {
            if contentAlignment == .center {
                titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            } else {
                titleLabel.setContentHuggingPriority(.required, for: .horizontal)
            }
        }
    }
    
    // MARK: - Private

    private let titleLabel = UILabel()
    private let gestureBarView = UIView()
    private let tintView = UIView()
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let feedback = UISelectionFeedbackGenerator()
    
    private var menuPresentationObserver: Any!
    
    private var contents: MenuContents?
    private var theme: MenuTheme
    private var longPress: UILongPressGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    
    private let itemsSource: () -> [MenuItem]
    
    private var gestureStart: Date = .distantPast
    
    private var isShowingContents: Bool {
        return contents != nil
    }
    
    // --
    
    public init(title: String, theme: MenuTheme, itemsSource: @escaping () -> [MenuItem]) {
        self.itemsSource = itemsSource
        self.title = title
        self.theme = theme
        super.init(frame: .zero)
        
        // init title label
        titleLabel.text = title
        titleLabel.textColor = theme.darkTintColor
        titleLabel.textAlignment = .center
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        // init clipping view
        let clippingView = UIView()
        clippingView.clipsToBounds = true
        addSubview(clippingView)
        clippingView.layer.cornerRadius = 8.0
        clippingView.addSubview(effectView)
        clippingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // init layout for effectView
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        effectView.contentView.addSubview(tintView)
        effectView.contentView.addSubview(titleLabel)
        effectView.contentView.addSubview(gestureBarView)
        
        // init layout for tint view
        tintView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // init layout for title label
        titleLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }
        
        // init gesture bar view
        gestureBarView.layer.cornerRadius = 1.0
        gestureBarView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(2)
            make.width.equalTo(20)
            make.bottom.equalToSuperview().inset(3)
        }
        
        // init long press gesture recog
        longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressGesture(_:)))
        longPress.minimumPressDuration = 0.0
        longPress.delegate = self
        addGestureRecognizer(longPress)
        
        // init tap gesture recog
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
        
        // set given theme
        applyTheme(theme)
        
        // add observer for menu will present notification
        NotificationCenter.default.addObserver(forName: MenuView.dismissMenu, object: nil, queue: nil) { [weak self] (noti) in
            self?.hideContents(animated: true)
        }
        menuPresentationObserver = NotificationCenter.default.addObserver(forName: MenuView.menuWillPresent, object: nil, queue: nil) { [weak self] notification in
            if let poster = notification.object as? MenuView, let this = self, poster !== this {
                self?.hideContents(animated: false)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(menuPresentationObserver)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

// MARK: - Public Interface

extension MenuView {
    
    public func showContents() {
        NotificationCenter.default.post(name: MenuView.menuWillPresent, object: self)
        
        let contents = MenuContents(name: title, items: itemsSource(), theme: theme)
        for view in contents.stackView.arrangedSubviews {
            if let view = view as? MenuItemView {
                var updatableView = view
                updatableView.updateLayout = {
                    [weak self] in
                    
                    self?.relayoutContents()
                }
            }
        }
        addSubview(contents)
        contents.snp.makeConstraints { make in
            switch contentAlignment {
            case .left:
                make.top.right.equalToSuperview()
            case .right:
                make.top.left.equalToSuperview()
            case .center:
                make.top.centerX.equalToSuperview()
            }
        }
        
        effectView.isHidden = true
        
        longPress?.minimumPressDuration = 0.07
        
        self.contents = contents
        
        setNeedsLayout()
        layoutIfNeeded()
        
        contents.generateMaskAndShadow(alignment: contentAlignment)
        contents.focusInitialViewIfNecessary()
        
        feedback.prepare()
        contents.highlightChanged = {
            [weak self] in
            
            self?.feedback.selectionChanged()
        }
    }
    
    public func hideContents(animated: Bool) {
        let contentsView = contents
        contents = nil
        
        longPress?.minimumPressDuration = 0.0
        
        effectView.isHidden = false
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                contentsView?.alpha = 0.0
            }) {
                finished in
                contentsView?.removeFromSuperview()
            }
        } else {
            contentsView?.removeFromSuperview()
        }
    }
    
}

// MARK: - Private Interface

extension MenuView {
    
    private func relayoutContents() {
        if let contents = contents {
            setNeedsLayout()
            layoutIfNeeded()
            
            contents.generateMaskAndShadow(alignment: contentAlignment)
        }
    }
    
}

// MARK: - Gesture Recognition

extension MenuView {
    
    @objc private func longPressGesture(_ sender: UILongPressGestureRecognizer) {
        
        // Highlight whatever we can
        if let contents = self.contents {
            let localPoint = sender.location(in: self)
            let contentsPoint = convert(localPoint, to: contents)
            
            if contents.pointInsideMenuShape(contentsPoint) {
                contents.highlightedPosition = CGPoint(x: contentsPoint.x, y: localPoint.y)
            }
        }
        
        switch sender.state {
        case .began:
            if !isShowingContents {
                gestureStart = Date()
                showContents()
            } else {
                gestureStart = .distantPast
            }
            
            contents?.isInteractiveDragActive = true
        case .cancelled:
            fallthrough
        case .ended:
            
            let gestureEnd = Date()
            contents?.isInteractiveDragActive = false
            if gestureEnd.timeIntervalSince(gestureStart) > 0.3 {
                selectPositionAndHideContents(sender)
            }
            
            // hide the menu on touch end:
            //contents?.isInteractiveDragActive = false
            //hideContents(animated: true)
            
            
        default:
            ()
        }
    }
    
    @objc private func tapped(_ sender: UITapGestureRecognizer) {
        selectPositionAndHideContents(sender)
    }
    
    private func selectPositionAndHideContents(_ gesture: UIGestureRecognizer) {
        if let contents = contents {
            let point = convert(gesture.location(in: self), to: contents)
            
            if contents.point(inside: point, with: nil) {
                contents.selectPosition(point, completion: {
                    [weak self] menuItem in
                    
                    self?.hideContents(animated: true)
                    
                    menuItem.performAction()
                })
            } else {
                hideContents(animated: true)
            }
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == longPress && otherGestureRecognizer == tapGesture {
            return true
        }
        return false
    }
    
}

// MARK: - Hit Testing

extension MenuView {
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let contents = contents else {
            return super.point(inside: point, with: event)
        }
        
        let contentsPoint = convert(point, to: contents)
        
        if !contents.pointInsideMenuShape(contentsPoint) {
            hideContents(animated: true)
        }
        
        return contents.pointInsideMenuShape(contentsPoint)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let contents = contents else {
            return super.hitTest(point, with: event)
        }
        
        let contentsPoint = convert(point, to: contents)
        
        if !contents.pointInsideMenuShape(contentsPoint) {
            hideContents(animated: true)
        } else {
            return contents.hitTest(contentsPoint, with: event)
        }
        
        return super.hitTest(point, with: event)
    }
    
}

// MARK: - Theming

extension MenuView {
    
    public func applyTheme(_ theme: MenuTheme) {
        self.theme = theme
        
        titleLabel.font = theme.font
        titleLabel.textColor = theme.darkTintColor
        gestureBarView.backgroundColor = theme.gestureBarTint
        tintView.backgroundColor = theme.backgroundTint
        effectView.effect = theme.blurEffect
        
        contents?.applyTheme(theme)
    }
    
    public override func tintColorDidChange() {
        titleLabel.textColor = tintColor
    }
    
}
