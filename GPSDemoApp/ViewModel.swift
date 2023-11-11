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
}

struct RowSearchResult {
    let edge: Edge
    let interceptCoordinate: Coordinate
    let row:RowStreetSweeping
    let product: Double
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

    var rows: [RowStreetSweeping] {
        get {
            StreetSweepMgr.shared.rows
        }
    }

    var matchedIntercept: Coordinate!

    var matchedEdge: Edge!

    var foundRow: RowStreetSweeping!

    private func tailRow() -> LocationLogEntry? {
        return LocationLog.shared.all.last
    }

    private func findSchedule(_ coord: CLLocationCoordinate2D, then thenDo: @escaping (RowSearchResult?)->(Void)) {
//        DispatchQueue(label: "\(self)").async {
            self.searchInternal(coord, then: thenDo)
//        }
    }

    func sweepLocation() -> Coordinate? {
        if let l = tailRow() {
            return Coordinate(latitude: l.lat, longitude: l.long)
        }
        return nil
    }

    func sweepScheduleSearch(_ loc: Coordinate, then doThisShit: @escaping (RowStreetSweeping?)->(Void)) {
        let loc = delegate.targetLocation()

        findSchedule(loc, then: {
            res in

            if let row = res?.row {

                doThisShit(row)
            }
            else {
                doThisShit(nil)
            }
        })
    }

    private func searchInternal(_ coord: CLLocationCoordinate2D, then doThis: @escaping ((RowSearchResult)?)->(Void)) {

        var dResult = Double.infinity
        var rowResult: RowSearchResult! = nil

        for row in StreetSweepMgr.shared.rows {

            // NOTE: somehwere remember that intercept search will exclude where the point falls outside the segment
            let rpair = row.interceptSearch(near: coord)

            // TODO: this should move to the row type not in viewmodel
            let searchR = RowSearchResult(edge: rpair.1, interceptCoordinate: rpair.2, row: rpair.0, product: rpair.3)
            let rEdge = searchR.edge
            let int = searchR.interceptCoordinate

            if searchR.product < dResult
            {
                // TODO: remember to set matchedEdge+matchedIntercept once final resultl found
                rowResult = searchR

                dResult = searchR.product

                print("prefering nearer result: \(rowResult.row.name)(\(dResult))")
            }
            else {
                //print("skipping result: \(rowResult.row.name) run: \(dRun))")
            }
        }

        guard let rowResult = rowResult else {
            return
        }

        matchedEdge = rowResult.edge
        matchedIntercept = rowResult.interceptCoordinate

        doThis(rowResult)
    }

    func refreshFromCursor() {

        if let delegate = delegate {
            let curs = delegate.targetLocation()
            delegate.updateSchedule(Coordinate(latitude: curs.latitude, longitude: curs.longitude))
        }
    }
    
    override init() {
        super.init()

        MyLocationManager.shared.startObserving {
            (location) in
            self.delegate.updatedMyLocation(location.coordinate)
        }
    }
    
    deinit {
        MyLocationManager.shared.stopObserving()
    }
}



