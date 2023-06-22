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
    var city: String
    var inputstream: InputStream!

    static var shared = StreetSweepMgr(city: Config.city)

    init(city: String) {
        self.city = city

        super.init()

        load()
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
                rows += [RowStreetSweeping(nit)]
            }
        }
        catch let error {
            print (error)
            fatalError()
        }
    }

    func findSchedule(_ coord: CLLocationCoordinate2D) -> RowStreetSweeping? {
        var result: RowStreetSweeping = rows.first!

        let findArea: (RowStreetSweeping, CLLocationCoordinate2D) -> Double = {
            row, coord in
            // thing
            let dab = sqrt( pow((row.lineB.latitude - row.lineA.latitude), 2) + pow(row.lineB.longitude - row.lineA.longitude,2) )
            let dlatA = (coord.latitude - row.lineA.latitude) / dab
            let dlngA = (coord.longitude - row.lineA.longitude) / dab
            let dlatB = (coord.latitude - row.lineB.latitude) / dab
            let dlngB = (coord.longitude - row.lineB.longitude) / dab

            let cah = sqrt(
                dlatA*dlatA + dlngA*dlngA
            )
            let cbh = sqrt(
                dlatB*dlatB + dlngB*dlngB
            )

            let a = (cah * cbh) / 2
            return a
        }

        for row in rows {
            var area = findArea(row, coord)
            if area < findArea(result, coord) {
                result = row
                print("improving result: \(row.values) area \(area)")
            }
        }
        return result
    }
}
