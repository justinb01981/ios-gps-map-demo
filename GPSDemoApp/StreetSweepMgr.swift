//
//  StreetSweepMgr.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 6/13/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import SQLite

fileprivate let city = "sf"

class StreetSweepMgr: NSObject {

    var rows: [RowStreetSweeping] = []
    var indexedByCenterline: [String: [RowStreetSweeping]] = [:]
    var city: String
    var inputstream: InputStream!

    weak var result: RowStreetSweeping!
    var matchedIntercept: Coordinate!
    var matchedEdge: Edge!

    static var shared = StreetSweepMgr(city: Config.city)

    init(city: String) {
        self.city = city

        super.init()

        loadTest()
//        load()
    }

    private func loadTest()
    {
        let row1 = ["1191000", "1627862", "LINESTRING (-122.418747573844 37.75543693624, -122.419857942892 37.755365729245)", "22nd St", "Friday", "Fri", "6", "8", "1", "1", "1", "1", "1", "L"]
        let row2 = ["2665000", "1643917", "LINESTRING (-122.479106356666 37.776546338205, -122.480175347783 37.776497608827)", "Balboa St", "Fri 2nd & 4th", "Fri", "9", "11", "0", "1", "0", "1", "0", "L"]
        let row3 = ["4730000", "1604605", "LINESTRING (-122.379106356666 37.786546338205, -122.379106356666 37.716546338205)", "Detroit St", "Mon 2nd & 4th", "Mon", "12", "14", "0", "1", "0", "1", "0", "L"]
        let row4 = ["13336000", "1599251", "LINESTRING (-122.444336617908 37.734557437918, -122.444336333905 37.734717369765, -122.444406257688 37.734813056491, -122.444694857171 37.735018825585, -122.445044465977 37.73524073449, -122.445321236327 37.735477044094)", "Vista Verde Ct", "Thu 2nd & 4th", "Thu", "12", "14", "0", "1", "0", "1", "0", "L"]

        for r in [
           row1
          ,row2
          ,row3
          ,row4
        ] {
            rows += [RowStreetSweeping(r)!]
        }

        sanity()
    }

    private func sanity()
    {
        // math sanity
        var r1 = RowStreetSweeping(
            ["1191000", "1627862", "LINESTRING (-10 10, 10 -10)", "22nd St", "Friday", "Fri", "6", "8", "1", "1", "1", "1", "1", "L"]
        )!

        let rc = Coordinate(-1, -1)
        let rc1 = Coordinate(-1.5, -1)
        let rc2 = Coordinate(-1, -3)
        //        assert(r1.intercept(rc, r1....
        //        print("\(r1.intercept(rc, Coordinate(-1, 1), Coordinate(1, -1)))")
        //        print("\(r1.intercept(rc1, Coordinate(-1, 1), Coordinate(1, -1)))")
        print("\(intercept(rc2, Coordinate(-3, 1), Coordinate(3, -2)))")
    }

    private func load()
    {
        // TODO: add query for nyc:
        // http://www.opencurb.nyc/search.php?coord=40.7630131962117,-73.9860065204115&v_type=PASSENGER&a_type=PARK&meter=0&radius=50&StartDate=2015-09-30&StartTime=06:25&EndDate=2015-09-30&EndTime=07:25&action_allowed=1

        let path =  Bundle.main.path(forResource: "sweep_schedule_\(city)", ofType: "db")!

        // Wrap everything in a do...catch to handle errors
        do {
            let db = try Connection("\(path)")
            let schedule = Table(TABLE_NAME)
            let it = try! db.prepare(schedule.select(selectBindings)).makeIterator()

            while let nit = it.next() {
                var values: [String] = []

                for b in selectBindings {
                    values += [try! nit.get(b)]
                } // for b

                if let nrow = RowStreetSweeping(values) {

                    indexedByCenterline[nrow.name, default: []] += [nrow]
                    indexedByCenterline[nrow.name] = indexedByCenterline[nrow.name]?.sorted(by: { $0.cnn < $1.cnn })
                    rows += [nrow]
                    // will be added to rows after indexing
                }
            }// while
        }
        catch let error {
            print (error)
            fatalError()
        }

        // connect sibling rows for right/left side
        for sibling in self.rows {
            if sibling.sideOppositeRow != nil { continue }

            // link
            sibling.sideOppositeRow = indexedByCenterline[sibling.name]?.first(where: { $0 != sibling })
            sibling.sideOppositeRow?.sideOppositeRow = sibling
        }
    }

    private var dResult = Double.infinity

    private func searchInternal(_ coord: CLLocationCoordinate2D, then doThis: @escaping (RowStreetSweeping?)->(Void)) {
        
        //self.result = nil

        var dResult = Double.infinity
        var tResult: RowStreetSweeping! = nil

        for row in rows {

            if let rpair = row.interceptSearch(near: coord) {

                let xcoord = rpair.0
                let int = rpair.1
                let dist = rpair.2

                let dInt = dist2(int.latitude, int.longitude, coord.latitude, coord.longitude)

                if dInt < dResult
                {
                    matchedEdge = rpair.0
                    matchedIntercept = int
                    tResult = row
                    dResult = dInt

//                    print("improving result: \(tResult.name) / \(dResult) weight: \(tResult.dResult)")
                }
            }
        }

        print("approx row: \(rows.max(by: {$0.dResult > $1.dResult})?.name ?? "nil" )")

        DispatchQueue.main.async {
            self.dResult = dResult
            self.result = tResult
            //print("results: \(self.rows.sorted(by: { $0.dResult < $1.dResult }).map { $0.name })")
            doThis(self.result)
        }
    }

    func findSchedule(_ coord: CLLocationCoordinate2D, then thenDo: @escaping (RowStreetSweeping?)->(Void)) {
        DispatchQueue(label: "\(self)").async {
            self.searchInternal(coord, then: thenDo)
        }
    }
}

