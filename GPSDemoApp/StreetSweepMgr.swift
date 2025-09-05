//
//  StreetSweepMgr.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 6/13/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//

//import Foundation
import UIKit
import CoreLocation
import SQLite

fileprivate let city = "sf"
fileprivate let CNN_SEARCH = "13168101"

class StreetSweepMgr: NSObject {

    var rows: [RowStreetSweeping] = []
    var indexedByCenterline: [Int: [RowStreetSweeping]] = [:]
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
        // located near "MISSION DISTRICT" on map - testing - see "foreign cinemas"
        let row1 = ["9102000","Mission St","Julia St  -  08th St",
                    "L","SouthEast","Thursday","Thu","2","6","1","1","1","1","1","1", "1618894","LINESTRING (-122.412413343787 37.778045328617, -122.413157691449 37.777457419935)"]
        let row2 = ["1191000","22nd St","Mission St  -  Bartlett St","L","South","Friday","Fri","6","8","1","1","1","1","1","0","1627862","LINESTRING (-122.418747573844 37.75543693624, -122.419857942892 37.755365729245)"]

        //let row3 = ["4730000", "1604605", "LINESTRING (-122.405317 37.785734, -122.407517 37.78634)", "Detroit St", "Mon 2nd & 4th", "Mon", "12", "14", "0", "1", "0", "1", "0", "L"]
//        let row4 = ["13336000", "1599251", "LINESTRING (-122.444336617908 37.734557437918, -122.444336333905 37.734717369765, -122.444406257688 37.734813056491, -122.444694857171 37.735018825585, -122.445044465977 37.73524073449, -122.445321236327 37.735477044094)", "Vista Verde Ct", "Thu 2nd & 4th", "Thu", "12", "14", "0", "1", "0", "1", "0", "L"]

        for r in [
            row1,
            row2,
            //row3
        ] {
            rows += [RowStreetSweeping(r)!]
        }
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
            let it = try! db.prepare(schedule.select(selectBindings as! [any Expressible])).makeIterator()

            while let nit = it.next() {

                var values: [String] = []
                var ignored = false

                selectBindings.forEach {
                    ex in


                    do {
                        if let ex = ex as? SQLite.Expression<String> {
                            let val = try nit.get(ex)

                            values += [ val ]
                        }
                        else if let ex = ex as? SQLite.Expression<Int> {
                            let val = try nit.get(ex)

                            values += [ String(val) ]
                        }

                    }
                    catch let ex {
                        print("sql exception: \(ex)")

                        ignored = true
                    }

                }

                if !ignored, values.count > 0,// CNN_SEARCH == values[0],
                    let nrow = RowStreetSweeping(values) {

                    indexedByCenterline[nrow.cnn, default: []] += [nrow]
                    indexedByCenterline[nrow.cnn] = indexedByCenterline[nrow.cnn]?.sorted(by: { $0.cnn < $1.cnn })
                    rows += [nrow]

                    print("OK: added row \(nrow)")

                    // will be added to rows after indexing
                }
                else {
                    //fatalError()
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
            sibling.sideOppositeRow = indexedByCenterline[sibling.cnn]?.first(where: { $0 != sibling && $0.side != sibling.side })
            sibling.sideOppositeRow?.sideOppositeRow = sibling
        }
    }
}

