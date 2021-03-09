//
//  LocationLog.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/7/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import Foundation

fileprivate let key = "LocationLog"

class LocationLogEntry: NSObject, NSCoding {

    var lat: Double!
    var long: Double!
    var time: Date!
    
    init(lat: Double, long: Double, time: Date) {
        self.lat = lat
        self.long = long
        self.time = time
    }
    
    required init(coder encoder: NSCoder) {
        super.init()
        self.lat = encoder.decodeObject(forKey: "lat") as? Double
        self.long = encoder.decodeObject(forKey: "long") as? Double
        self.time = encoder.decodeObject(forKey: "time") as? Date
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(lat, forKey: "lat")
        coder.encode(long, forKey: "long")
        coder.encode(time, forKey: "time")
    }
}

class LocationLog: NSObject {
    
    static var shared = LocationLog()
    
    var all: [LocationLogEntry] = []
    
    override init() {
        super.init()
        
        if UserDefaults.standard.array(forKey: key) == nil {
            UserDefaults.standard.set([], forKey: key)
        }
        
        guard let allData = UserDefaults.standard.value(forKey: key) as? [Data] else {
            fatalError()
        }
        
        for entry in allData {
            if let next = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(entry) as? LocationLogEntry {
                all += [next]
            }
        }
    }
    
    func logLocation(_ entry: LocationLogEntry) {
        
        all.append(entry)
        
        var storage: [Data] = []
        
        for entry in all {
            storage += [ try! NSKeyedArchiver.archivedData(withRootObject: entry, requiringSecureCoding: false) ]
        }
        
        UserDefaults.standard.set(storage, forKey: key)
    }
    
    func flush() {
        all.removeAll()
        UserDefaults.standard.set([], forKey: key)
    }
}
