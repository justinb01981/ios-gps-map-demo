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
// MUST MATCH ENUM
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

fileprivate let ICPTA: Int = -1
fileprivate let ICPTB: Int = 0
fileprivate let ORDINALS = [
    "1st",
    "2nd",
    "3rd",
    "4th",
    "5th"
]
fileprivate let weekDays = [ "Sun", "Mon", "Tues", "Wed", "Thu", "Fri", "Sat", "Holiday"]

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
fileprivate let THEWEEK = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "holiday"]

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

    var line: [Coordinate]
    var lineLength: Double
    var name: String
    var weekOfMonth: [Int]

    var schedText: String
    var schedHourFrom: Int
    var schedHourTo: Int


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

                return Coordinate(    latitude: Double(s[1])!, longitude: Double(s[0])! )
            }

            // happens below

            // TODO: respect column names from csv - e.g.
            // 7641000,Judah St,06th Ave  -  07th Ave,L,South,Wed 2nd & 4th,Wed,7,8,0,1,0,1,0,0,1638646,"LINESTRING (-122.462972001083 37.762315769364, -122.46404200546 37.762268848832)"
            cnn = Int(values[RowFields.CNN.rawValue])!
            name = String(values[RowFields.Corridor.rawValue])

            // format here ex:
            // "Wed 2nd and 4th"

            let dayName = String(values[RowFields.WeekDay.rawValue])

            let fieldRaw = String(values[RowFields.Limits.rawValue])

            // don't forget to trim the commas ,
            let fieldComp = fieldRaw.components(separatedBy: " ").map({ $0.trimmingCharacters(in: CharacterSet(charactersIn: ",")) })
            if fieldComp.count > 1 {
                print("fieldComp w/ord found: \(fieldComp)")
            }

            weekOfMonth = []    // construct this set from the schedule text
            for ordMaybe in fieldComp {
                if let x = ORDINALS.firstIndex(where: { $0 == ordMaybe }) {
                    weekOfMonth += [x+1]    // weeks start at 1
                }
                else {
                    print("WARN: ignoring weekOfMonth token: \(ordMaybe)")
                }
            }

            if weekOfMonth.count == 0 {
                weekOfMonth = [1, 2, 3, 4]
            }
            else {
                print("cool: weekOfMonth = \(weekOfMonth)")
            }

            blockSweepId = Int(values[RowFields.BlockSweepID.rawValue])!
            corridor = values[RowFields.Corridor.rawValue]
            // ignore values2, limits
            side = values[RowFields.CNNRightLeft.rawValue] == "R" ? .R : .L
            schedText = values[RowFields.Limits.rawValue]

            // from/to time-string parsing
            guard let schedHourFrom = Int(values[RowFields.FromHour.rawValue]),
                  let schedHourTo = Int(values[RowFields.ToHour.rawValue])
            else {
                fatalError("failed parsing FromHour / ToHour from \(values[RowFields.FromHour.rawValue])")
            }
            self.schedHourFrom = schedHourFrom
            self.schedHourTo = schedHourTo

            let dname = self.values[RowFields.Limits.rawValue].components(separatedBy: " ").first!

            if dname.lowercased() == "holiday" {
                //dname = "Sunday" // TODO: FIX THIS once I'm sane again
                print("WARN: ignoring Holiday csv rows!")
                return nil
            }

            dayI = 0
            if let i = THEWEEK.firstIndex(where: { $0.contains(dname.lowercased()) }) {
                dayI = i
            }

            lineLength = 0
            for idx in 0..<tokes.count {

                let vtxn = tokes[idx]
                let rise = vtxn.latitude / vtxn.longitude
                let la = rise * (  side == .R ? (MINRUN) : (-MINRUN)  )
                //* (side == .L ? LEFTRIGHT_BIAS : -LEFTRIGHT_BIAS)
                let lo = la  
                // * (side == .L ? LEFTRIGHT_BIAS : -LEFTRIGHT_BIAS)
                let vtx = [Coordinate(latitude: vtxn.latitude   + la,
                                                  longitude: vtxn.longitude + lo)  ]

                // HACK: tweak coordinates lat/long slightly so the rows for r/l are distinct and can be highlighted on the map
                self.line += vtx

                if idx > 0 {
                    lineLength += dist2(line[idx+ICPTA].latitude, line[idx+ICPTA].longitude, line[idx+ICPTB].latitude, line[idx+ICPTB].longitude)
                    // calculating full length
                }
            }
        }
        else {
            print("ignoring empty line: \(values)")
            return nil
        }
    }



    static let rowSchedFormat: (RowStreetSweeping)->(String) = { s in

        let df = DateFormatter()
        df.dateFormat = "YYYY-MM-dd HH:mm"
//        df.timeZone = Calendar.current.timeZone
        let expS = s.timeExpireOnLocal()
        return "\(df.string(from: expS))\n'\(s.schedText) " + "@ \(s.schedHourFrom)'"
    }


    static let scheduleFormat:(RowStreetSweeping)->(String) = { s in
        return "\(rowSchedFormat(s)) "  //\n \(rowSchedFormat(s.sideOppositeRow!))"
    }
}

extension RowStreetSweeping {
    func timeExpireOnLocal() -> Date {

        // HACK: using a n extern singleton here
        let cal = gCalendarMgr.userCalendar

        let p: Calendar.MatchingPolicy = .nextTime

        var nextDateResult: Date! = .distantFuture

        for o in weekOfMonth {

            // TODO: use weekdayOrdinal
            if let tmp  =
                cal.nextDate(after: Date(), matching: .init(timeZone: cal.timeZone, weekday: dayI+1),
                             matchingPolicy: p) {

                // TODO: if week of month matches

                if abs(nextDateResult.timeIntervalSinceNow) > abs(tmp.timeIntervalSinceNow) {
                    nextDateResult = tmp
                }
            }
        }

        print("\(self) timeExpireOnLocal(): \(nextDateResult)")

        return nextDateResult.advanced(by: Double(schedHourFrom) * 3600.0)
    }
}

extension RowStreetSweeping {
    func fullRouteCoordinates() -> [Coordinate] {
        let row = self
        var result: [Coordinate] = []
        var selectedRows: [RowStreetSweeping] = []

        let hackGlobalSingleton = StreetSweepMgr.shared

        for rowS in hackGlobalSingleton.rows {
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

    func dotProduct(_ c: Coordinate) -> Double {
        var max = 0.0
        for i in 1..<line.count
        {
            let d = VectorDotProduct((line[i+ICPTA], line[i+ICPTB]), c)
            if d > max
            {
                max = d
            }
        }
        return max
    }

    func distanceToVertex(_ coord: Coordinate) -> Double {
        // return distance to nearest vertex
        return self.line.map( { dist2($0.latitude, $0.longitude, coord.latitude, coord.longitude) }).min()!
    }

    // TODO: minimal intercept for this row edges.. split out the math maybe
    // TODO: unit vectors

    // update weights of all rows based on cursor
    func interceptSearch(near coord: Coordinate) -> (RowStreetSweeping, Edge, Coordinate, Double) {

        var dResult: Double = .infinity
        var icptR: Coordinate = .init(.infinity, .infinity)
        var eResult: Edge = (icptR, icptR)

        for i in 1..<line.count {   // for each edge...

            let a = line[i+ICPTA]
            let b = line[i+ICPTB]

            let intercep = intercept(coord, a, b)
            let D = dist2(a.latitude, a.longitude, coord.latitude, coord.longitude)
            let Dedge = dist2(a.latitude, a.longitude, b.latitude, b.longitude)

            // respect direction - depending on which side of the line

            let direction: StreetSide = (intercep.latitude - coord.latitude) / (b.latitude - a.latitude) > 0 ? .L : .R

            // if D is > segment length forget it
            if direction == side &&
                D < Dedge &&   // NO - test range of each line segment
                D < dResult {  // lineLength fudge ?

                icptR = intercep
                eResult = (b, a)
                dResult = D
            }
        }

        return (self, eResult, icptR, dResult)
    }

}

func intercept(_ c: Coordinate, _ a: Coordinate, _ b: Coordinate) -> Coordinate {

    // find intersection where y = Mx + b, a being the origin
    let ABlat = (b.latitude-a.latitude)
    let ABlng = (b.longitude-a.longitude)

    // if rise is slope lat/lng
    let rise = ABlng / ABlat

    // U = lat
    // V = lng
    //
    let AClat = (c.latitude-a.latitude)
    let BClat = (c.latitude-b.latitude)
    let AClng = (c.longitude-a.longitude)
    let BClng = (c.longitude-b.longitude)

    // use lat for lng cmponent of intercept (walk along X, then from there walk along Y

    let u = AClng / rise
    let v = u * rise

//    print("""
//    rise=\(rise)
//    v=\(v)
//    u=\(u)
//    """)

    return Coordinate(a.latitude+u, a.longitude+v)
}
