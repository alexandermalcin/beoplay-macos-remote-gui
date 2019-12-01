//
//  StatusMenuController.swift
//  BeoplayRemoteGUI
//
//  Created by Thomas L. Kjeldsen on 03/06/2019.
//

import Cocoa
import RemoteCore

class StatusMenuController: NSObject {
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var volumeLevelView: VolumeLevelView!
    @IBOutlet weak var volumeLevelSlider: NSSlider!
    @IBOutlet weak var volumeLevelMenuItem: NSMenuItem!
    @IBOutlet weak var sourcesMenuItem: NSMenuItem!
    @IBOutlet weak var tuneinMenuItem: NSMenuItem!
    @IBOutlet weak var deviceSeparatorMenuItem: NSMenuItem!
    @IBOutlet weak var separatorMenuItem: NSMenuItem!

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var deviceController = DeviceController()
    private var remoteControl = RemoteControl()
    private var lastVolumeLevel: Int = 0
    private var ignoreReceivedVolumeUpdates = false
    private var debouncer: DispatchWorkItem? = nil

    override func awakeFromNib() {
        statusItem.button?.title = UserDefaults.standard.string(forKey: "app.title") ?? "BeoplayRemote"
        statusItem.menu = statusMenu
        volumeLevelMenuItem.view = volumeLevelView

        if UserDefaults.standard.bool(forKey: "hotkeys.enabled") {
            setupHotkeys()
        }

        if UserDefaults.standard.bool(forKey: "tuneIn.enabled") {
            setupTuneIn()
        }
    
        setupDeviceDiscovery()
    }

    private func setupDeviceDiscovery() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.deviceController.menuController = DeviceMenuController(self)
            self.remoteControl.startDiscovery(delegate: self.deviceController)
        }
    }

    private func setupVolumeUpdateReceiver() {
        // read the current volume level and receive updates on future volume levels
        DispatchQueue.global(qos: .userInitiated).async {
            self.remoteControl.receiveVolumeNotifications(volumeUpdate: self.receiveVolumeUpdate, connectionUpdate: self.deviceController.menuController!.connectionUpdate(state:message:))
        }
    }

    private func receiveVolumeUpdate(vol: Int?) {
        DispatchQueue.main.async {
            if (vol == nil) {
                return
            }

            if self.ignoreReceivedVolumeUpdates {
                NSLog("receive: \(vol!)  (ignored!)")
            } else {
                self.lastVolumeLevel = vol!
                self.volumeLevelSlider.integerValue = self.lastVolumeLevel
                NSLog("receive: \(self.lastVolumeLevel)")
            }
        }
    }

    private func sendVolumeUpdate(vol: Int) {
        self.remoteControl.setVolume(volume: vol)
        NSLog("send: \(vol)")
    }

    private func setupHotkeys() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        if !isTrusted {
            NSLog("hotkeys setup failed:  required permission to 'control this computer using accessibility features' is missing")
        } else {
            NSLog("hotkeys setup")

            let defaultVolumeStep = 4
            let step: Int = UserDefaults.standard.integer(forKey: "hotkeys.VolumeStep") > 0 ?
                            UserDefaults.standard.integer(forKey: "hotkeys.VolumeStep") : defaultVolumeStep
            NSLog("hotkeys.VolumeStep: \(step)")

            enum Command : String {
                case Leave, Join, PrevSource, NextSource, Back, TogglePlayPause, Next, Mute, VolumeDown, VolumeUp
            }

            enum Hotkey : String {
                case F1  = "122"
                case F2  = "120"
                case F3  =  "99"
                case F4  = "118"
                case F5  =  "96"
                case F6  =  "97"
                case F7  =  "98"
                case F8  = "100"
                case F9  = "101"
                case F10 = "109"
                case F11 = "103"
                case F12 = "111"
            }

            let defaultConfiguration = [
                Hotkey.F1  : Command.Leave,
                Hotkey.F2  : Command.Join,
                Hotkey.F5  : Command.PrevSource,
                Hotkey.F6  : Command.NextSource,
                Hotkey.F7  : Command.Back,
                Hotkey.F8  : Command.TogglePlayPause,
                Hotkey.F9  : Command.Next,
                Hotkey.F10 : Command.Mute,
                Hotkey.F11 : Command.VolumeDown,
                Hotkey.F12 : Command.VolumeUp
            ]

            let hotkeyMap = Dictionary(uniqueKeysWithValues:
                defaultConfiguration.compactMap() { hotkey, command -> (UInt16, Command)? in
                    let strKeycode = UserDefaults.standard.string(forKey: "hotkeys.\(command)") ?? hotkey.rawValue
                    if let keycode = UInt16(strKeycode, radix: 10) {
                        NSLog("hotkeys.\(command): \(strKeycode)")
                        return (keycode, command)
                    } else {
                        return nil
                    }
                }
            )

            NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { (event) in
                guard let command = hotkeyMap[event.keyCode] else {
                    return
                }

                NSLog("hotkey command: \(command)")

                switch(command) {
                case Command.Leave:
                    self.remoteControl.leave()
                    break
                case Command.Join:
                    self.remoteControl.join()
                    break
                case Command.PrevSource:
                    NSLog("Not implemented")
//                    self.setSource(self.sourcesMenuItem!.submenu!.item(at: 2) as! NSMenuItem)
                    break
                case Command.NextSource:
                    NSLog("Not implemented")
//                    self.setSource(self.sourcesMenuItem!.submenu!.item(at: 3) as! NSMenuItem)
                    break
                case Command.Back:
                    self.remoteControl.backward()
                    break
                case Command.TogglePlayPause:
                    NSLog("Not implemented")
                    break
                case Command.Next:
                    self.remoteControl.forward()
                    break
                case Command.Mute:
                    NSLog("Not implemented")
                    break
                case Command.VolumeDown:
                    self.remoteControl.adjustVolume(delta: -step)
                    break
                case Command.VolumeUp:
                    self.remoteControl.adjustVolume(delta: step)
                    break
                }
            }
        }
    }

    private func refreshSources() {
        NSLog("refresh sources")

        self.remoteControl.getEnabledSources { (sources: [BeoplaySource]) in
            var hideTypes: [String] = []

            if let tmp = UserDefaults.standard.array(forKey: "sources.hideTypes") {
                hideTypes = tmp.map { ($0 as! String).lowercased() }
            }

            self.sourcesMenuItem.submenu?
                .items
                .filter { $0.representedObject != nil }
                .forEach { self.sourcesMenuItem.submenu!.removeItem($0) }
            
            self.sourcesMenuItem.isHidden = false
            self.separatorMenuItem.isHidden = false

            var hasTuneIn = false
            
            for source in sources {
                if hideTypes.contains(source.sourceType.lowercased()) {
                    continue
                }

                if source.sourceType == "TUNEIN" {
                    hasTuneIn = true
                }

                var name: String
                if source.borrowed {
                    name = "\(source.friendlyName) (\(source.productFriendlyName))"
                } else {
                    name = source.friendlyName
                }

                let item = NSMenuItem(title: name, action: #selector(self.setSource(_:)), keyEquivalent: "")
                item.representedObject = source.id
                item.target = self
                item.isEnabled = true
                self.sourcesMenuItem.submenu?.addItem(item)
                NSLog("source id: \(source.id), source name: \(name)")
            }

            if UserDefaults.standard.bool(forKey: "tuneIn.enabled") {
                self.tuneinMenuItem.isHidden = !hasTuneIn
            }
        }
    }

    private func setupTuneIn() {
        let order = UserDefaults.standard.array(forKey: "tuneIn.order")!
        let stations = UserDefaults.standard.dictionary(forKey: "tuneIn.stations")!

        self.tuneinMenuItem.isHidden = false
        self.separatorMenuItem.isHidden = false

        for id in order {
            let name = stations[id as! String] as! String
            let item = NSMenuItem(title: name, action: #selector(tuneIn(_:)), keyEquivalent: "")
            item.representedObject = id
            item.target = self
            item.isEnabled = true
            self.tuneinMenuItem.submenu?.addItem(item)
            NSLog("tuneIn radio station id: \(id), station name: \(name)")
        }
    }

    @IBAction func setSource(_ sender: NSMenuItem) {
        let id = sender.representedObject as! String
        self.remoteControl.setSource(id: id)
        NSLog("setSource: \(id)")
    }

    @IBAction func tuneIn(_ sender: NSMenuItem) {
        let id = sender.representedObject as! String
        self.remoteControl.tuneIn(id: id, name: sender.title)
        NSLog("tuneIn: \(id)")
    }

    @IBAction func sliderMoved(_ sender: NSSlider) {
        func debounce(seconds: TimeInterval, function: @escaping () -> ()) {
            self.debouncer?.cancel()
            self.debouncer = DispatchWorkItem {
                function()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: self.debouncer!)
        }

        let eventType = sender.window?.currentEvent?.type
        let volume = sender.integerValue

        if self.lastVolumeLevel != volume {
            self.lastVolumeLevel = volume

            if !self.ignoreReceivedVolumeUpdates {
                NSLog("user is moving the slider (preventing slider wobbliness)")
                self.ignoreReceivedVolumeUpdates = true
            }

            self.sendVolumeUpdate(vol: volume)

            debounce(seconds: 1) {
                NSLog("user is no longer moving the slider")
                self.ignoreReceivedVolumeUpdates = false
            }
        }

        if eventType == NSEvent.EventType.leftMouseUp {
            self.ignoreReceivedVolumeUpdates = false

            // close the menu
            self.statusMenu.cancelTracking()
        }
    }

    func connectDevice(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? NetService else {
            return
        }

        NSLog("connectDevice \"\(device.name)\", \(device.hostName!):\(device.port)")

        self.remoteControl.stopVolumeNotifications()
        self.remoteControl = RemoteControl()
        self.remoteControl.setEndpoint(host: device.hostName!, port: device.port)
        self.setupVolumeUpdateReceiver()

        self.deviceController.menuController?.selectDeviceMenuItem(sender)

        if UserDefaults.standard.bool(forKey: "sources.enabled") {
            self.refreshSources()
        }
    }

    @IBAction func deviceClicked(_ sender: NSMenuItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.connectDevice(sender)
            NSLog("device")
        }
    }

    @IBAction func joinClicked(_ sender: Any) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.remoteControl.join()
            NSLog("join")
        }
    }

    @IBAction func leaveClicked(_ sender: Any) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.remoteControl.leave()
            NSLog("leave")
        }
    }

    @IBAction func playClicked(_ sender: NSMenuItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.remoteControl.play()
            NSLog("play")
        }
    }

    @IBAction func pauseClicked(_ sender: NSMenuItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.remoteControl.pause()
            NSLog("pause")
        }
    }

    @IBAction func forwardClicked(_ sender: NSMenuItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.remoteControl.forward()
            NSLog("forward")
        }
    }

    @IBAction func backwardClicked(_ sender: NSMenuItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.remoteControl.backward()
            NSLog("backward")
        }
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
        NSLog("quit")
    }
}
