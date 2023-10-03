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

struct RowSearchResult {
    let edge: Edge
    let interceptCoordinate: Coordinate
    let row:RowStreetSweeping
    let dotProduct: Double
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

        //self.result = nil

        var dResult = Double.infinity
        var rowResult: RowSearchResult! = nil

        for row in StreetSweepMgr.shared.rows {
            print("search row \(row.name)")

            let rpair = row.interceptSearch(near: coord)

            if !false
            {
                guard let rpair = rpair else {
                    fatalError("you broke something")
                }

                //
                //(RowStreetSweeping, Edge, Coordinate, Double)?
                // todo: fix this stupid mapping-to-closure debt
                let sRes = RowSearchResult(edge: rpair.1, interceptCoordinate: rpair.2, row: rpair.0, dotProduct: rpair.3)

                let rEdge = sRes.edge
                let int = sRes.interceptCoordinate

//                let dRun = dist2(int.latitude, int.longitude, coord.latitude, coord.longitude)
                let dRun = sRes.dotProduct

                if dRun < dResult &&
//                    dRun > MINRUN && dRun < MAXRUN
                    dist2(rEdge.0.latitude, rEdge.0.longitude, rEdge.1.latitude, rEdge.1.longitude) > MINRUN // skip short edges?
//                    &&
//                    laC > 0.0 && laC < 1.0 &&
//                    loC > 0.0 && loC < 1.0
                {

                    matchedEdge = rEdge
                    matchedIntercept = int
                    rowResult = sRes

                    dResult = dRun
                    print("improving result: \(rowResult.row.name) run: \(dRun)")
                }
                else {
                    //print("skipping result: \(rowResult.row.name) run: \(dRun))")
                }
            }
        }

//        DispatchQueue.main.async {
            // self.foundRow set elsewhere
//            print("results: \(self.rows.sorted(by: { $0.dResult < $1.dResult }).map { $0.name })")
            doThis(rowResult)
//        }
    }

    func refreshFromCursor() {

        if let delegate = delegate {
            let curs = delegate.targetLocation()
            delegate.updateSchedule(Coordinate(latitude: curs.latitude, longitude: curs.longitude))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
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



