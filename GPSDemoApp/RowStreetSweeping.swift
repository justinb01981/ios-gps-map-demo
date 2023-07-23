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

fileprivate let wktpfx = "LINESTRING ("
fileprivate let THEWEEK = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "Holiday"]

typealias RowValues = [String]

enum StreetSide: String {
    case L = "L"
    case R = "R"
    case Unknown = ""
}

enum RowFields: Int {
    /*
     printing description of an:
     ▿ 14 elements
       - 0 : "9102000"
       - 1 : "1618894"
       - 2 : "LINESTRING (-122.412413343787 37.778045328617, -122.413157691449 37.777457419935)"
       - 3 : "Mission St"
       - 4 : "Thursday"
       - 5 : "Thu"
       - 6 : "2"
       - 7 : "6"
       - 8 : "1"
       - 9 : "1"
       - 10 : "1"
       - 11 : "1"
       - 12 : "1"
       - 13 : "L"

     */

    case CNN = 0
    case BlockSweepID = 1
    case Corridor = 3
    case Limits = 4
    case CNNRightLeft = 13
//    case BlockSide
//    case FullName = "corridorFullName"
    case WeekDay = 5
    case FromHour = 6
    case ToHour = 7
    case Week1 = 8
    case Week2 = 9
    case Week3 = 10
    case Week4 = 11
    case Week5 = 12
//    case Holidays
    case Holidays = 14

    case Line = 2
    case Last = 16
}

class RowStreetSweeping: NSObject {

    var line: [CLLocationCoordinate2D]
    var name: String
    var schedText: String
    var timeRemain: Double
    var dayI: Int
    var blockSweepId: Int

    // https://data.sfgov.org/City-Infrastructure/Street-Sweeping-Schedule/yhqp-riqs
    var cnn: Int          // centerline network number
    var corridor: String          // 9th ave, etc
    var side: StreetSide
    var sideOppositeRow: RowStreetSweeping?

    var values: [String]

    init?(_ an: RowValues) {
        guard an.count != RowFields.Last.rawValue else {
            return nil
        }

        values = an // moved outside hack

        let lineVals = values[RowFields.Line.rawValue]

        // see https://www.ibm.com/docs/en/db2/11.1?topic=formats-well-known-text-wkt-representation
        if lineVals.count > wktpfx.count {

            line = []

            // trim LINESTRING
            let left = lineVals.index(lineVals.startIndex, offsetBy: (wktpfx.count))
            let right = lineVals.index(lineVals.endIndex, offsetBy: -1)
            let linev = lineVals[left..<right]

            // "hehe. tokes
            let tokes = linev.components(separatedBy: ", ").map {
                let s = $0.components(separatedBy: " ")
                assert(s.count == 2)

                return CLLocationCoordinate2D(    latitude: Double(s[1])!, longitude: Double(s[0])! )
            }

            // happens below

            // TODO: respect column names from csv - e.g.
            // 7641000,Judah St,06th Ave  -  07th Ave,L,South,Wed 2nd & 4th,Wed,7,8,0,1,0,1,0,0,1638646,"LINESTRING (-122.462972001083 37.762315769364, -122.46404200546 37.762268848832)"
            cnn = Int(values[RowFields.CNN.rawValue])!
            name = values[RowFields.Corridor.rawValue]
            blockSweepId = Int(values[RowFields.BlockSweepID.rawValue])!
            corridor = values[RowFields.Corridor.rawValue]
            // ignore values2, limits
            side = values[RowFields.CNNRightLeft.rawValue] == "R" ? .R : .L
            schedText = values[RowFields.WeekDay.rawValue] + " " + values[RowFields.FromHour.rawValue]

            let cal = Calendar(identifier: .gregorian)

            let dname = self.values[RowFields.WeekDay.rawValue]

            if let dayI = THEWEEK.firstIndex(where: { $0.contains(dname) }) {

                guard let dest = cal.nextDate(after: Date(), matching: DateComponents(day: dayI+1), matchingPolicy: .nextTime)
                else {
                    fatalError()
                }

                self.dayI = dayI
                timeRemain = Double(dest.timeIntervalSince(Date())  / 86400 )//days
            }
            else
            {
                timeRemain = 0
                fatalError()
            }

            for idx in 0..<tokes.count {

                let vtxn = tokes[idx]
//                let la = -1 / vtxn.latitude / vtxn.longitude * (side == .L ? 0.00000000001 : -0.00000000001)
//                let lo = -1 / vtxi.latitude / vtxi.longitude * (side == .L ? -0.00000000001 : 0.00000000001)
                let vtx = [CLLocationCoordinate2D(latitude: vtxn.latitude /*  + (side == .L ? 0.000000000000001 : -0.000000000000001)*/ ,
                                                  longitude: vtxn.longitude /*   + (side == .L ? 0.000000000000001 : -0.000000000000001) */)  ]

                // HACK: tweak coordinates lat/long slightly so the rows for r/l are distinct and can be highlighted on the map
                self.line += vtx
            }
        }
        else {
            print("ignoring empty line: \(values)")
            return nil
        }
    }
}

extension StreetSweepMgr {
    func fullRouteCoordinates(_ row: RowStreetSweeping) -> [CLLocationCoordinate2D] {
        var result: [CLLocationCoordinate2D] = []

        var selectedRows: [RowStreetSweeping] = []

        // HACK: accessing the singleton from an instance
        for rowS in StreetSweepMgr.shared.rows {
            
            // find contiguous coordinates
            if rowS.cnn == row.cnn
                // && rowS.corridor == row.corridor
                //&& rowS.side == row.side
            {                               // fuck your styleguide

                if let l = selectedRows.last, l.cnn < rowS.cnn {
                    selectedRows = selectedRows + [rowS]
                }
                else {
                    selectedRows = [rowS] + selectedRows
                }
            }
        }

        for row in selectedRows { result += row.line }

        return result
    }
}

extension RowStreetSweeping {
    func scheduleText() -> String {
        // TODO: diff colors for opposite sides text
        return "\(self.schedText) + \(self.timeRemain/86400.0) days remain"
    }

    func streetText() -> String { return name + "(\(self.side == .R ? "right side" : "left side"))" }
}
