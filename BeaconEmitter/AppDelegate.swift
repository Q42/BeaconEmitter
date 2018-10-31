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
  var currentBeacon: BNMBeaconRegion? {
    didSet {
      beaconChanged()
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    manager = CBPeripheralManager(delegate: self, queue: nil)
    beacons = [
    ]
    beaconsTableView.dataSource = self
    beaconsTableView.delegate = self
    beaconsTableView.reloadData()
    if manager.isAdvertising {
      startBeaconButton.title = "Turn iBeacon off"
    } else {
      startBeaconButton.title = "Turn iBeacon on"
    }
  }

  private func beaconChanged() {
    switch (manager.isAdvertising, currentBeacon) {
    case (true, .some(let beacon)):
      manager.stopAdvertising()
      startBeaconButton.title = "Turn iBeacon on"
      let measuredPower = getMeasuredPower()
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1)) {
        self.manager.startAdvertising(beacon.peripheralData(withMeasuredPower: measuredPower) as! [String: Any])
      }
    case (false, .some(let beacon)):
      manager.startAdvertising(beacon.peripheralData(withMeasuredPower: getMeasuredPower()) as! [String: Any])
      startBeaconButton.title = "Turn iBeacon off"
    case (true, .none):
      manager.stopAdvertising()
      startBeaconButton.title = "Turn iBeacon on"
    case (false, .none):
      manager.stopAdvertising()
      startBeaconButton.title = "Turn iBeacon on"
    }
  }

  // MARK: - Actions

  func getMeasuredPower() -> NSNumber? {
    if power.intValue != 0 {
      return NSNumber(value: power.intValue)
    } else {
      return nil
    }
  }

  @IBAction func changeBeaconState(_ sender: NSButton) {
    if manager.isAdvertising {
      currentBeacon = nil
    } else {
      if let beacon = createBeaconFromInput() {
        currentBeacon = beacon
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
    major.stringValue = NumberFormatter.localizedString(from: beaconRegion.major, number: .none)
    minor.stringValue = NumberFormatter.localizedString(from: beaconRegion.minor, number: .none)
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

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    if let error = error {
      let alert = NSAlert(error: error)
      alert.runModal()
    } else {
      startBeaconButton.title = "Turn iBeacon off"
    }
  }
}

extension AppDelegate: NSTableViewDataSource, NSTableViewDelegate {
  private struct CellIdentifier {
    static let title = "titleCell"
    static let major = "majorCell"
    static let minor = "minorCell"
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
      text = beacon.identifier
      cellIdentifier = CellIdentifier.title
    } else if tableColumn == tableView.tableColumns[1] {
        text = NumberFormatter.localizedString(from: beacon.major, number: .none)
        cellIdentifier = CellIdentifier.major
    } else if tableColumn == tableView.tableColumns[2] {
      text = NumberFormatter.localizedString(from: beacon.minor, number: .none)
      cellIdentifier = CellIdentifier.minor
    } else if tableColumn == tableView.tableColumns[3] {
      text = beacon.proximityUUID.uuidString
      cellIdentifier = CellIdentifier.uuid
    } else {
      return nil
    }

    guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView else { return nil }

    cell.textField?.stringValue = text
    return cell
  }

  func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
    let beacons: NSArray = self.beacons as NSArray
    if let x = beacons.sortedArray(using: tableView.sortDescriptors) as? [BNMBeaconRegion] {
      self.beacons = x
      tableView.reloadData()
    }
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    guard let beacon = beacons[safe: beaconsTableView.selectedRow] else { return }
    print(beacon.proximityUUID.uuidString)
    setInputsFromBeacon(beaconRegion: beacon)
    currentBeacon = beacon
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
