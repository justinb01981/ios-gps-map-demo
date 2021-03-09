//
//  MyLocationManager.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/5/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import Foundation
import CoreLocation

class MyLocationManager: NSObject {
    static var shared = MyLocationManager()
    
    private let locManager = CLLocationManager()
    private var updateLocationBlock: ((CLLocation)->Void)?
    
    func startObserving(doThisWhenMoved: @escaping (CLLocation)->Void) {
        
        locManager.delegate = self
        
        updateLocationBlock = doThisWhenMoved
        
        locManager.requestWhenInUseAuthorization()
    }
    
    func stopObserving() {
        locManager.stopUpdatingLocation()
    }
    
    func restart() {
        guard let tmp = updateLocationBlock else {
            fatalError()
        }
        
        stopObserving()
        
        MyLocationManager.shared = MyLocationManager()
        
        MyLocationManager.shared.startObserving(doThisWhenMoved: tmp)
        
        print("\(self) restart done")
    }
}

extension MyLocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("\(self): location manager authorization changed")
        
        locManager.distanceFilter = Settings.shared.distance // meters
        locManager.desiredAccuracy = Settings.shared.accuracy
        locManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations: [CLLocation]) {
        guard let loc = didUpdateLocations.last else {
            return
        }
        
        print("\(self): updated location: \(loc)")
        
        LocationLog.shared.logLocation(LocationLogEntry(lat: loc.coordinate.latitude, long: loc.coordinate.longitude, time: loc.timestamp))
        
        updateLocationBlock?(loc)
    }
}
