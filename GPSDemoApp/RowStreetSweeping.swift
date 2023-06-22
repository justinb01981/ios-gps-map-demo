//
//  RowStreetSweeping.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 6/17/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//

import Foundation
import MapKit
import SQLite


let TABLE_NAME = "street_sweeping_sf"
let TableStreetSweeping = SQLite.Table(TABLE_NAME)
let SELECT_QUERY = "SELECT Line FROM \(TABLE_NAME)"
let selectBindings: [Expression<String>] = [Expression<String>("CNN"),
                                            Expression<String>("BlockSweepID"),
                                            Expression<String>("Line"),
                                            Expression<String>("Corridor"),
                                            Expression<String>("FullName"),
                                            Expression<String>("WeekDay"),
                                            Expression<String>("FromHour"),
                                            Expression<String>("ToHour"),
                                            Expression<String>("Week1"),Expression<String>("Week2"),
                                            Expression<String>("Week3"),
                                            Expression<String>("Week4"),Expression<String>("Week5"), Expression<String>("CNNRightLeft")

                                            ]
fileprivate let selectBindingLineIdx = 2 // match above


//CNN,Corridor,Limits,CNNRightLeft,BlockSide,FullName,WeekDay,FromHour,ToHour,Week1,Week2,Week3,Week4,Week5,Holidays,BlockSweepID,Line
/*
var cnn: SQLite.ColumnDefinition = .init(name: "CNN", type: .TEXT)
var corridor: SQLite.ColumnDefinition = .init(name: "Corridor", type: .TEXT)
var limits: SQLite.ColumnDefinition = .init(name: "Limits", type: .TEXT)
var cnnRightLeft: SQLite.ColumnDefinition = .init(name: "CNNRightLeft", type: .TEXT)
var blockSide: SQLite.ColumnDefinition = .init(name: "BlockSide", type: .TEXT)
var fullName: SQLite.ColumnDefinition = .init(name: "FullName", type: .TEXT)
var weekDay: SQLite.ColumnDefinition = .init(name: "WeekDay", type: .TEXT)
var fromHour: SQLite.ColumnDefinition = .init(name: "FromHour", type: .TEXT)
var toHour: SQLite.ColumnDefinition = .init(name: "ToHour", type: .NUMERIC)
var week1: SQLite.ColumnDefinition = .init(name: "Week1", type: .TEXT)
var week2: SQLite.ColumnDefinition = .init(name: "Week2", type: .TEXT)
var week3: SQLite.ColumnDefinition = .init(name: "Week3", type: .TEXT)
var week4: SQLite.ColumnDefinition = .init(name: "Week4", type: .TEXT)
var week5: SQLite.ColumnDefinition = .init(name: "Week5", type: .TEXT)
var holidays : SQLite.ColumnDefinition = .init(name: "Holidays", type: .TEXT)
// TODO: primary key
var blockSweepId: SQLite.ColumnDefinition = .init(name: "BlockSweepID", type: .TEXT)
var line: SQLite.ColumnDefinition = .init(name: "Line", type: .TEXT)
*/


class RowStreetSweeping {

    var lineA: CLLocationCoordinate2D
    var lineB: CLLocationCoordinate2D
    var values: [String] = []

    var lineBinding = Expression<String>("Line")

    init(_ an: Row) {
        for b in selectBindings {
            values += [try! an.get(b)]
        }

        // HACK: -- magic index - see query
        let line = values[selectBindingLineIdx]

        let tokes = line.components(separatedBy: " ").map {
            var s = $0
            s = s.replacingOccurrences(of: "LINESTRING ", with: "")
            s = s.replacingOccurrences(of: "(", with: "")
            s = s.replacingOccurrences(of: ",", with: "")
            s = s.replacingOccurrences(of: ")", with: "")
            return s
        }

        self.lineA = CLLocationCoordinate2D()
        self.lineB = CLLocationCoordinate2D()

        guard tokes.count >= 4 else {
            print("LINESTRING column empty value? (\(line)")
            return
        }

        var off = 1 // skip leading linestring
        self.lineA.latitude = Double(tokes[off])!
        off += 1
        self.lineA.longitude = Double(tokes[off])!
        off += 1
        self.lineB.latitude = Double(tokes[off])!
        off += 1
        self.lineB.longitude = Double(tokes[off])!
        off += 1
    }
}
