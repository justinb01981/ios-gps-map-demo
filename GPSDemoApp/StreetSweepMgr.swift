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
    var indexedByCNN: [Int: [RowStreetSweeping]] = [:]
    var city: String
    var inputstream: InputStream!

    static var shared = StreetSweepMgr(city: Config.city)

    init(city: String) {
        self.city = city

        super.init()

//        loadTest()
        load()
    }

    private func loadTest()
    {
        let row1 = ["1191000", "1627862", "LINESTRING (-122.418747573844 37.75543693624, -122.419857942892 37.755365729245)", "22nd St", "Friday", "Fri", "6", "8", "1", "1", "1", "1", "1", "L"]
        let row2 = ["2665000", "1643917", "LINESTRING (-122.479106356666 37.776546338205, -122.480175347783 37.776497608827)", "Balboa St", "Fri 2nd & 4th", "Fri", "9", "11", "0", "1", "0", "1", "0", "L"]
        let row3 = ["4730000", "1604605", "LINESTRING (-122.444320397518 37.733087687592, -122.444320121546 37.733811072758)", "Detroit St", "Mon 2nd & 4th", "Mon", "12", "14", "0", "1", "0", "1", "0", "L"]
        let row4 = ["13336000", "1599251", "LINESTRING (-122.444336617908 37.734557437918, -122.444336333905 37.734717369765, -122.444406257688 37.734813056491, -122.444694857171 37.735018825585, -122.445044465977 37.73524073449, -122.445321236327 37.735477044094)", "Vista Verde Ct", "Thu 2nd & 4th", "Thu", "12", "14", "0", "1", "0", "1", "0", "L"]

        for r in [row1, row2, row3, row4] {
            rows += [RowStreetSweeping(r)!]
        }
    }

    private func load()
    {
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
                    rows += [nrow]
                    indexedByCNN[nrow.cnn, default: []] += [nrow]
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
            sibling.sideOppositeRow = indexedByCNN[sibling.cnn]?.first(where: { $0 != sibling })
            sibling.sideOppositeRow?.sideOppositeRow = sibling
        }
    }

    private weak var result: RowStreetSweeping?

    private func searchInternal(_ coord: CLLocationCoordinate2D, then doThis: @escaping (RowStreetSweeping?)->(Void)) {

        var result: RowStreetSweeping!

        for row in rows {
            if result == nil || result.dotProduct(coord) > row.dotProduct(coord) {
                result = row
//                print("improving result: \(row.name) / \(row.dotProduct(coord))")
            }
        }

        DispatchQueue.main.async {
            doThis(result)
        }
    }

    func findSchedule(_ coord: CLLocationCoordinate2D, then thenDo: @escaping (RowStreetSweeping?)->(Void)) {
        DispatchQueue(label: "\(self)").async {
            self.searchInternal(coord, then: thenDo)
        }
    }
}

