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

// TODO: tweak this based on rows
fileprivate let LEFTRIGHT_BIAS = 0.0000000000001

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
    var lineLength: Double
    var name: String
    var schedText: String
    var timeExpire: Date
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

            var dname = self.values[RowFields.WeekDay.rawValue]

            if dname == "Holiday" {
                //dname = "Sunday" // TODO: FIX THIS once I'm sane again
                return nil
            }

            if let dayI = THEWEEK.firstIndex(where: { $0.contains(dname) }) {

                guard let dest = cal.nextDate(after: Date(), matching: DateComponents(weekday: dayI+1), matchingPolicy: .nextTime)
                else {
                    fatalError()
                }
                self.timeExpire = dest
                self.dayI = dayI
            }
            else
            {
                timeExpire = Date(timeIntervalSince1970: 0.0)
                fatalError()
            }

            lineLength = 0

            for idx in 0..<tokes.count {

                let vtxn = tokes[idx]
                let rise = vtxn.latitude / vtxn.longitude
                let la = 0.0 //vtxn.latitude * (-1 / rise) * (side == .L ? LEFTRIGHT_BIAS : -LEFTRIGHT_BIAS)
                let lo = 0.0 //vtxn.longitude / (-1 / rise) * (side == .L ? LEFTRIGHT_BIAS : -LEFTRIGHT_BIAS)
                let vtx = [CLLocationCoordinate2D(latitude: vtxn.latitude   + la,
                                                  longitude: vtxn.longitude + lo)  ]

                // HACK: tweak coordinates lat/long slightly so the rows for r/l are distinct and can be highlighted on the map
                self.line += vtx

                if idx > 0 {
                    lineLength += dist2(line[idx].latitude, line[idx].longitude, line[idx-1].latitude, line[idx-1].longitude)// calculating full length
                }
            }
        }
        else {
            print("ignoring empty line: \(values)")
            return nil
        }
    }

    static let rowSchedFormat: (RowStreetSweeping)->(String) = { s in
        return "\(s.timeExpire)\n\(s.schedText)"
    }


    static let scheduleFormat:(RowStreetSweeping)->(String) = { s in
        return "\(rowSchedFormat(s)) "  //\n \(rowSchedFormat(s.sideOppositeRow!))"
    }
}

extension StreetSweepMgr {
    func fullRouteCoordinates(_ row: RowStreetSweeping) -> [CLLocationCoordinate2D] {
        var result: [CLLocationCoordinate2D] = []
        var selectedRows: [RowStreetSweeping] = []

        for rowS in rows {
            // find contiguous coordinates
            if //rowS.cnn == row.cnn
                rowS.corridor == row.corridor
                && rowS.side == row.side
            {
                selectedRows += [rowS]
            }
        }

        selectedRows = selectedRows.sorted(by: { $0.cnn < $1.cnn })

        selectedRows.forEach({ result += $0.line })
        
        return result
    }
}

extension RowStreetSweeping {

    func scheduleText() -> String {
        return RowStreetSweeping.scheduleFormat(self)
    }

    func streetText() -> String { return name + "(\(self.side == .R ? "right side" : "left side"))" }

    func dotProduct(_ c: CLLocationCoordinate2D) -> Double {
        var min = Double.infinity
        for i in 1..<line.count
        {
            let d = VectorDotProduct((line[i-1], line[i]), c)
            if d < min
            {
                min = d
            }
        }
        return min
    }

    func distanceToVertex(_ coord: CLLocationCoordinate2D) -> Double {
        // return distance to nearest vertex
        return self.line.map( { dist2($0.latitude, $0.longitude, coord.latitude, coord.longitude) }).min()!
    }
}
