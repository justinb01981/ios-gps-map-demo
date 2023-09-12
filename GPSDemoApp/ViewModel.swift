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
    func updatedMyLocation(_ c: Coordinate)
    func updateSchedule(_ c: Coordinate)
    func targetLocation() -> Coordinate
    func replaceTarget(_ c: Coordinate)
}

class ViewModel: NSObject {
    weak var delegate: ViewModelDelegate!

    static let kLocationLogKey = "loggedLocations"

    var routes: [String: [Coordinate]] = [:]

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

    var matchedIntercept: Coordinate! {
        get {
            StreetSweepMgr.shared.matchedIntercept
        }
    }

    var matchedEdge: Edge! {
        get {
            StreetSweepMgr.shared.matchedEdge
        }
    }

    var foundRow: RowStreetSweeping!

    private func tailRow() -> LocationLogEntry? {
        return LocationLog.shared.all.last
    }

    func sweepLocation() -> Coordinate? {
        if let l = tailRow() {
            return Coordinate(latitude: l.lat, longitude: l.long)
        }
        return nil
    }

    func sweepScheduleSearch(_ loc: Coordinate, then doThisShit: @escaping (RowStreetSweeping?)->(Void)) {
        let loc = delegate.targetLocation()

        foundRow = nil

        StreetSweepMgr.shared.findSchedule(loc, then: {
            row in
            self.foundRow = row
            doThisShit(row)
        })
    }

    func refreshFromCursor() {

        if let delegate = delegate {
            let curs = delegate.targetLocation()
            delegate.updateSchedule(Coordinate(latitude: curs.latitude, longitude: curs.longitude))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            [weak self] in
            self?.refreshFromCursor()
        }
    }
    
    override init() {
        super.init()

        MyLocationManager.shared.startObserving {
            (location) in
            self.delegate.updatedMyLocation(location.coordinate)
        }

        refreshFromCursor()
    }
    
    deinit {
        MyLocationManager.shared.stopObserving()
    }
}
