//
//  ViewModel.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/5/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

protocol ViewModelDelegate: NSObject {
    func updatedMyLocation(_ c: CLLocationCoordinate2D)
    func updateSchedule(_ c: CLLocationCoordinate2D)
    func targetLocation() -> CLLocationCoordinate2D
    func replaceTarget(_ c: CLLocationCoordinate2D)
}

class ViewModel: NSObject {
    weak var delegate: ViewModelDelegate!

    static let kLocationLogKey = "loggedLocations"

    var routes: [String: [CLLocationCoordinate2D]] = [:]

    var allLocations: [LocationLogEntry] {
        get {
            return LocationLog.shared.all
        }
    }
    
    var distance: Double = Settings.shared.distance {
        didSet {
            Settings.shared.distance = distance
            MyLocationManager.shared.restart()
        }
    }
    
    var accuracy: Double = Settings.shared.accuracy {
        didSet {
            Settings.shared.accuracy = accuracy
            MyLocationManager.shared.restart()
        }
    }

    private func tailRow() -> LocationLogEntry? {
        return LocationLog.shared.all.last
    }

    func sweepLocation() -> CLLocationCoordinate2D? {
        if let l = tailRow() {
            return CLLocationCoordinate2D(latitude: l.lat, longitude: l.long)
        }
        return nil
    }

    func sweepScheduleSearch(_ loc: CLLocationCoordinate2D, then doThisShit: @escaping (RowStreetSweeping?)->(Void)) {
        let loc = delegate.targetLocation()

        StreetSweepMgr.shared.findSchedule(loc, then: {
            schedOpt in
            doThisShit(schedOpt)
        })
    }

    func refreshFromCursor() {

        if let delegate = delegate {
            let curs = delegate.targetLocation()
            delegate.updateSchedule(CLLocationCoordinate2D(latitude: curs.latitude, longitude: curs.longitude))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            [weak self] in
            self?.refreshFromCursor()
        }
    }
    
    override init() {
        super.init()

        MyLocationManager.shared.startObserving { (location) in
            self.delegate.updatedMyLocation(location.coordinate)
        }

        refreshFromCursor()
    }
    
    deinit {
        MyLocationManager.shared.stopObserving()
    }
}
