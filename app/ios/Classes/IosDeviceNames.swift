// IosDeviceNames.swift
// Gets the device name of the current device based on modelIdentifier
// from a periodically fetched list stored at carat-web / ios-devices.csv.
//
//  Created by Lagerspetz, Eemil H on 29/01/2018.
//  Copyright © 2018 University of Helsinki. All rights reserved.
//

import Foundation

class IosDeviceNames: NSObject {
    
    //MARK: Class Properties

    // Singleton access
    static let sharedInstance = IosDeviceNames()
    // How often to re-fetch the list
    static let THRESH = UInt64(3600*24)
    // List file location
    static let url = "http://carat.cs.helsinki.fi/ios-devices.csv"

    //MARK: Instance Properties

    // Need a separate data model class because the last fetch time also needs to come from disk.
    var cache:DeviceCache? = nil
  
    //MARK: Initialization
    
    override init() {
        super.init()
        self.cache = loadCache()
        // If it's too old, schedule a fetch
        fetchDeviceListAsync()
    }
  
    // Fetch device list asynchronously to not block main thread.
    func fetchDeviceListAsync() {
        DispatchQueue.main.async {
            self.fetchDeviceListIfNeeded()
        }
    }
  
    // Fetch and store device list on disk.
    private func fetchDeviceList() {
        let list = try? String(contentsOf: URL(string: IosDeviceNames.url)!)
        print("Got list", list ?? "nil")
        if let gotList = list { // Compare with scala: val list = Some(Seq("a;c", "b;d")); list.map{gotList => ... }
            let lines = gotList.split(separator: "\n")
            print("Got lines ",lines)
            var deviceMap = [String: String]()
            for line in lines {
                let parts = line.split(separator: ";")
                if parts.count > 1 {
                    print("Line ", parts[0], " -> ", parts[1])
                    deviceMap[String(parts[0])] = String(parts[1])
                }
            }
            cache = DeviceCache(deviceMap:deviceMap, lastUpdated:UInt64(NSDate().timeIntervalSince1970))
            saveCache()
        }
    }
    
    // If the list in cache is nil,
    // or too long since last list update,
    // update the list.
    private func fetchDeviceListIfNeeded() {
        if let gotCache = self.cache {
            // If it's too old, schedule a fetch
            if gotCache.lastUpdated + IosDeviceNames.THRESH < UInt64(NSDate().timeIntervalSince1970) {
                print("Cache updated more than",IosDeviceNames.THRESH,"seconds ago, fetching now.")
                fetchDeviceList()
            }
            // else new enough, do nothing
        } else {
            // No cache at all, fetch
            print("Cache nil, fetching device list over the network.")
            fetchDeviceList()
        }
    }
    
    // Get the device name matching the given platform.
    
    func getDeviceName(platform: String) -> String {
        print("Platform is ", platform)
        fetchDeviceListIfNeeded()
        let deviceName = cache?.get(platform: platform)
        if let gotDevice = deviceName {
            return gotDevice
        } else {
            return platform
        }
    }
  
    //MARK: Private methods
    
    private func saveCache() {
        if let gotCache = cache {
            // What is the right way here? Cache may be null, in which case save should not be called at all...
            let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(gotCache, toFile: DeviceCache.ArchiveURL.path)
            if isSuccessfulSave {
                print("Cached Devices successfully saved.")
            } else {
                print("Failed to save cached devices.")
            }
        }
    }
    
    private func loadCache() -> DeviceCache?  {
        let c = NSKeyedUnarchiver.unarchiveObject(withFile: DeviceCache.ArchiveURL.path) as? DeviceCache
        print("Loaded cache from disk: ", c ?? "nil")
        return c
    }
}
