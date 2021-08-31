//
//  InfoImageView.swift
//  BeoplayRemoteGUI
//
//  Created by Alex on 26.08.21.
//

import Foundation
import SwiftUI
import Cocoa

extension Notification.Name {
    static let AppleInterfaceThemeChangedNotification = Notification.Name("AppleInterfaceThemeChangedNotification")
}

enum OSAppearance: Int {
    case light
    case dark
}

@IBDesignable
class InformationImageView: NSImageView {
    
    @IBInspectable var borderColor: NSColor = NSColor.clear {
        didSet {
            layer?.borderColor = borderColor.cgColor
        }
    }
    
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer?.borderWidth = borderWidth
        }
    }
    
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer?.cornerRadius = cornerRadius
        }
    }
    
    @IBInspectable var masksToBounds: Bool = true {
        didSet {
            layer?.masksToBounds = masksToBounds
        }
    }
    
    var osAppearance: OSAppearance = .light
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.setNeedsDisplay()
        getAppearance()
        listenToInterfaceChangesNotification()
    }
    
    func listenToInterfaceChangesNotification() {
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(interfaceModeChanged),
            name: .AppleInterfaceThemeChangedNotification,
            object: nil
        )
    }
    
    @objc func interfaceModeChanged(_: NSNotification) {
         getAppearance()
    }
    
    func getAppearance() {
        let appearanceDescription = NSApplication.shared.effectiveAppearance.debugDescription.lowercased()
        self.osAppearance = appearanceDescription.contains("dark") ? .dark : .light
        updateAppearance()
    }
    
    func updateAppearance() {
        DispatchQueue.main.async {
            switch self.osAppearance {
            case .light:
                self.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
            case .dark:
                self.layer?.backgroundColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.2).cgColor
            }
        }
    }
    
}

struct InfoImageView_Previews: PreviewProvider {
    @available(OSX 10.15.0, *)
    static var previews: some View {
        Text("")
    }
}
