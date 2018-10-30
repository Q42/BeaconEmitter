//
//  AppDelegate.swift
//  BeaconEmitter
//
//  Created by Mathijs Bernson on 30/10/2018.
//  Copyright © 2018 Q42. All rights reserved.
//

import Cocoa
import CoreBluetooth

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet private weak var uuid: NSTextField!
  @IBOutlet private weak var identifier: NSTextField!
  @IBOutlet private weak var major: NSTextField!
  @IBOutlet private weak var minor: NSTextField!
  @IBOutlet private weak var power: NSTextField!
  @IBOutlet private weak var startBeaconButton: NSButton!
  @IBOutlet private weak var bluetoothStatusLbl: NSTextField!

  @IBOutlet private weak var beaconsTableView: NSTableView!

  var manager: CBPeripheralManager!
  var beacons: [BNMBeaconRegion] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    manager = CBPeripheralManager(delegate: self, queue: nil)
    beacons = [
    ]
    beaconsTableView.dataSource = self
    beaconsTableView.delegate = self
    beaconsTableView.reloadData()
  }

  // MARK: - Actions

  @IBAction func changeBeaconState(_ sender: NSButton) {
    if manager.isAdvertising {
      manager.stopAdvertising()
      sender.title = "Turn iBeacon on"
    } else {
      let measuredPower: NSNumber?
      if power.intValue != 0 {
        measuredPower = NSNumber(value: power.intValue)
      } else {
        measuredPower = nil
      }
      if let beacon = createBeaconFromInput(), let data = beacon.peripheralData(withMeasuredPower: measuredPower) as? [String: Any] {
          manager.startAdvertising(data)
          sender.title = "Turn iBeacon off"
      } else {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = "The UUID format is invalid"
        alert.addButton(withTitle: "Ok")
        alert.alertStyle = .warning

        alert.runModal()
      }
    }
  }

  @IBAction func handleClickRefreshButton(_ sender: NSButton) {
    if manager.isAdvertising {
      manager.stopAdvertising()
      startBeaconButton.title = "Turn iBeacon off"
    }

    let proximityUUID = NSUUID.init()
    uuid.stringValue = proximityUUID.uuidString
  }

  @IBAction func handleClickCopyButton(_ sender: NSButton) {
    if let copyValue = uuid.stringValue as? NSString {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.writeObjects([copyValue])
    }
  }

  // MARK:

  private func createBeaconFromInput() -> BNMBeaconRegion? {
    if let proximityUUID = UUID(uuidString: uuid.stringValue) {
      let major = NSNumber(value: self.major.intValue)
      let minor = NSNumber(value: self.minor.intValue)
      let beacon = BNMBeaconRegion(proximityUUID: proximityUUID, major: major, minor: minor, identifier: nil)
      return beacon
    } else {
      return nil
    }
  }

  private func setInputsFromBeacon(beaconRegion: BNMBeaconRegion) {
    uuid.stringValue = beaconRegion.proximityUUID.uuidString
    identifier.stringValue = beaconRegion.identifier
    major.intValue = beaconRegion.major.int32Value
    minor.intValue = beaconRegion.minor.int32Value
  }
}

extension AppDelegate: CBPeripheralManagerDelegate {
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    switch peripheral.state {
    case .unknown:
      bluetoothStatusLbl.stringValue = "The current state of the peripheral manager is unknown; an update is imminent."
      startBeaconButton.isEnabled = false
    case .resetting:
      bluetoothStatusLbl.stringValue = "The connection with the system service was momentarily lost; an update is imminent."
      startBeaconButton.isEnabled = false
    case .unsupported:
      bluetoothStatusLbl.stringValue = "The platform doesn't support the Bluetooth low energy peripheral/server role."
      startBeaconButton.isEnabled = false
    case .unauthorized:
      bluetoothStatusLbl.stringValue = "The app is not authorized to use the Bluetooth low energy peripheral/server role."
      startBeaconButton.isEnabled = false
    case .poweredOff:
      bluetoothStatusLbl.stringValue = "Bluetooth is currently powered off"
      startBeaconButton.isEnabled = false
    case .poweredOn:
      bluetoothStatusLbl.stringValue = "Bluetooth is currently powered on and is available to use."
      startBeaconButton.isEnabled = true
    }
  }
}

extension AppDelegate: NSTableViewDataSource, NSTableViewDelegate {
  private struct CellIdentifier {
    static let uuid = "uuidCell"
  }

  func numberOfRows(in tableView: NSTableView) -> Int {
    return beacons.count
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let cellIdentifier: String
    let beacon = beacons[row]
    let text: String

    if tableColumn == tableView.tableColumns[0] {
      text = beacon.proximityUUID.uuidString
      cellIdentifier = CellIdentifier.uuid
    } else {
      return nil
    }

    guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView else { return nil }

    cell.textField?.stringValue = text
    return cell
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    guard let beacon = beacons[safe: beaconsTableView.selectedRow] else { return }
    print(beacon.proximityUUID.uuidString)
    setInputsFromBeacon(beaconRegion: beacon)
    manager.stopAdvertising()
    let measuredPower: NSNumber?
    if power.intValue != 0 {
      measuredPower = NSNumber(value: power.intValue)
    } else {
      measuredPower = nil
    }
    manager.startAdvertising(beacon.peripheralData(withMeasuredPower: measuredPower) as? [String: Any])
  }
}

public extension Array {
  public subscript (safe index: Int) -> Element? {
    return indices ~= index ? self[index] : nil
  }

  public func appending(_ element: Element?) -> [Element] {
    if let element = element {
      var result = self
      result.append(element)
      return result
    }

    return self
  }
}
