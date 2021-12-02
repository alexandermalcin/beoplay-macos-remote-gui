//
//  InfoImageView.swift
//  BeoplayRemoteGUI
//
//  Created by Alex on 26.08.21.
//

import Foundation
import Cocoa

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
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.setNeedsDisplay()
    }
    
    override func layout() {
        super.layout()
        self.layer?.backgroundColor = NSColor(named: NSColor.Name("ImageViewBackgroundColor"))?.cgColor
    }
    
}
