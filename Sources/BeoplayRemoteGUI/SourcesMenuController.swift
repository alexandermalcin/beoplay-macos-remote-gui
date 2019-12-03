//
//  SourcesMenuController.swift
//  BeoplayRemoteGUI
//
//  Created by Thomas L. Kjeldsen on 01/12/2019.
//

import Cocoa
import RemoteCore

public class SourcesMenuController {
    private let remoteControl: RemoteControl
    private let sourcesMenuItem: NSMenuItem
    private let tuneInMenuController: TuneInMenuController?
    private let separatorMenuItem: NSMenuItem
    private var hideTypes: [String] = []
    private var currentSourceId = ""

    public init(remoteControl: RemoteControl, tuneInMenuController: TuneInMenuController?, sourcesMenuItem: NSMenuItem, separatorMenuItem: NSMenuItem) {
        self.remoteControl = remoteControl
        self.tuneInMenuController = tuneInMenuController
        self.sourcesMenuItem = sourcesMenuItem
        self.separatorMenuItem = separatorMenuItem

        if let tmp = UserDefaults.standard.array(forKey: "sources.hideTypes") {
            hideTypes = tmp.map { ($0 as! String).lowercased() }
        }
    }

    public func addObserver() {
        NotificationCenter.default.addObserver(forName: Notification.Name.onSourceChange, object: nil, queue: nil) { (notification: Notification) -> Void in
            if let data = notification.userInfo?["data"] as? RemoteCore.Source {
                DispatchQueue.main.async {
                    self.currentSourceId = data.id

                    for item in self.sourcesMenuItem.submenu!.items[2...] {
                        if let x = item.representedObject as? String, x == data.id {
                            item.state = NSControl.StateValue.on
                        } else {
                            item.state = NSControl.StateValue.off
                        }
                    }
                    NSLog("source: \(data.id)")
                }
            }
        }
    }

    public func reload() {
        NSLog("reload sources")

        self.remoteControl.getEnabledSources { (sources: [BeoplaySource]) in
            DispatchQueue.main.async {
                self.sourcesMenuItem.submenu?
                    .items
                    .filter { $0.representedObject != nil }
                    .forEach { self.sourcesMenuItem.submenu!.removeItem($0) }

                var hasAnySources = false
                var hasTuneInSource = false

                for source in sources {
                    if self.hideTypes.contains(source.sourceType.lowercased()) {
                        continue
                    }

                    hasAnySources = true

                    if source.sourceType == "TUNEIN" {
                        hasTuneInSource = true
                    }

                    let name = source.borrowed
                        ? "\(source.friendlyName) (\(source.productFriendlyName))"
                        : source.friendlyName

                    let item = NSMenuItem(title: name, action: #selector(self.setSource(_:)), keyEquivalent: "")
                    item.representedObject = source.id
                    item.target = self
                    item.isEnabled = true
                    item.state = source.id == self.currentSourceId ? NSControl.StateValue.on : NSControl.StateValue.off
                    self.sourcesMenuItem.submenu?.addItem(item)
                    NSLog("source id: \(source.id), source name: \(name)")
                }

                self.setVisibility(hasAnySources: hasAnySources, hasTuneInSource: hasTuneInSource)
            }
        }
    }

    public func noDevicesAvailable() {
        self.setVisibility(hasAnySources: false, hasTuneInSource: false)
    }

    private func setVisibility(hasAnySources: Bool, hasTuneInSource: Bool) {
        self.sourcesMenuItem.isHidden = !hasAnySources
        self.separatorMenuItem.isHidden = !hasAnySources
        self.tuneInMenuController?.deviceHasTuneInSource(hasTuneInSource)
    }

    @IBAction func setSource(_ sender: NSMenuItem) {
        let id = sender.representedObject as! String
        self.remoteControl.setSource(id: id)
        NSLog("setSource: \(id)")
    }
}
