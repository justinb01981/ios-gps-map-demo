//
//  RowStreetSweeping.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 6/17/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//

//example
//7667000,Judah St,32nd Ave  -  33rd Ave,R,North,"Mon 1st, 3rd, 5th",Mon,7,8,1,0,1,0,1,0,1645938,"LINESTRING (-122.49092290915 37.761086890906, -122.491997472553 37.761039513834)"


import Foundation
import MapKit
import SQLite


typealias SQExpression = SQLite.Expression

let TABLE_NAME = "street_sweeping_sf"
let TableStreetSweeping = SQLite.Table(TABLE_NAME)
//let SELECT_QUERY = "SELECT Line FROM \(TABLE_NAME)"
// MUST MATCH ENUM
let selectBindings = [SQExpression<Int>("CNN"),
                      SQExpression<String>("Corridor"),
                      SQExpression<String>("Limits"),
                      SQExpression<String>("CNNRightLeft"),
                      SQExpression<String>("BlockSide"),
                      SQExpression<String>("FullName"),
                      SQExpression<String>("WeekDay"),
                      SQExpression<Int>("FromHour"),
                      SQExpression<Int>("ToHour"),
                      SQExpression<Int>("Week1"),
                      SQExpression<Int>("Week2"),
                      SQExpression<Int>("Week3"),
                      SQExpression<Int>("Week4"),
                      SQExpression<Int>("Week5"),
                      SQExpression<Int>("Holidays"),
                      SQExpression<Int>("BlockSweepID"),
                      SQExpression<String>("Line")

] as [Any]

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
    case Corridor = 1
    case Limits = 2
    case CNNRightLeft = 3
    case BlockSide = 4
    case FullName = 5
    case WeekDay = 6
    case FromHour = 7
    case ToHour = 8
    case Week1 = 9
    case Week2 = 10
    case Week3 = 11
    case Week4 = 12
    case Week5 = 13
    case Holidays = 14
    case BlockSweepID = 15
    case Line = 16
    case Last = 17
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
        guard an.count == RowFields.Last.rawValue else {
            fatalError()
        }
        
        values = an // moved outside hack

        let lineVals = values[RowFields.Line.rawValue]

        // see https://www.ibm.com/docs/en/db2/11.1?topic=formats-well-known-text-wkt-representation
        line = []

        // trim LINESTRING
        let left = lineVals.index(lineVals.startIndex, offsetBy: (wktpfx.count))
        let right = lineVals.index(lineVals.endIndex, offsetBy: -1)
        let linev = lineVals[left..<right]

//            // "hehe. tokes
        let tokes:[Coordinate] = linev.components(separatedBy: ", ").map( {
            tok in

            let ab = tok.components(separatedBy:" ")
            guard ab.count == 2, let lat = Double(ab[1]), let lng = Double(ab[0]) else {
                fatalError()
            }
            return Coordinate(latitude: lat, longitude: lng)
        })

        // happens below

        // TODO: respect column names from csv - e.g.
        // 7667000,Judah St,32nd Ave  -  33rd Ave,R,North,"Mon 1st, 3rd, 5th",Mon,7,8,1,0,1,0,1,0,1645938,"LINESTRING (-122.49092290915 37.761086890906, -122.491997472553 37.761039513834)"

        cnn = Int(values[RowFields.CNN.rawValue])!
        name = String(values[RowFields.Corridor.rawValue])

        if(cnn == 7667000)
        {
            print("found \(7667000)")
        }

        // format here ex:
        // "Wed 2nd and 4th"

        let dayName = String(values[RowFields.WeekDay.rawValue])

        let fieldRaw = String(values[RowFields.FullName.rawValue])

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
            weekOfMonth = [1, 2, 3, 4, 5]
        }
        else {
            print("cool: weekOfMonth = \(weekOfMonth)")
        }

        blockSweepId = Int(values[RowFields.BlockSweepID.rawValue])!
        corridor = values[RowFields.Corridor.rawValue]
        // ignore values2, limits
        side = values[RowFields.CNNRightLeft.rawValue] == "R" ? .R : .L
        schedText = values[RowFields.FullName.rawValue]

        // from/to time-string parsing
        guard let schedHourFrom = Int(values[RowFields.FromHour.rawValue]),
              let schedHourTo = Int(values[RowFields.ToHour.rawValue])
        else {
            fatalError("failed parsing FromHour / ToHour from \(values[RowFields.FromHour.rawValue])")
        }
        self.schedHourFrom = schedHourFrom
        self.schedHourTo = schedHourTo

        let dname = self.values[RowFields.FullName.rawValue].components(separatedBy: " ").first!

        if dname.lowercased() == "holiday" {
            //dname = "Sunday" // TODO: FIX THIS once I'm sane again
            print("WARN: ignoring Holiday csv rows!")
            return nil
        }

        dayI = 0
        if let i = THEWEEK.firstIndex(where: { $0.contains(dname.lowercased()) }) {
            dayI = i
        }

        //print("line: \(tokes)")

        lineLength = 0
        for idx in 0..<tokes.count {

            let vtxn = tokes[idx]
            let rise = vtxn.latitude / vtxn.longitude
            let la = rise * (  side == .R ? (MINRUN) : (-MINRUN)  ) * (side == .L ? LEFTRIGHT_BIAS : -LEFTRIGHT_BIAS)
            let lo = la * (side == .L ? LEFTRIGHT_BIAS : -LEFTRIGHT_BIAS)
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
                cal.nextDate(after: Date(), matching: .init(timeZone: cal.timeZone, weekday: dayI+1, weekdayOrdinal: o),
                             matchingPolicy: p) {

                // TODO: if week of month matches

                if abs(nextDateResult.timeIntervalSinceNow) > abs(tmp.timeIntervalSinceNow) {
                    nextDateResult = tmp
                }
                else {
                    print("timeExpireOnLocal \(tmp) result ignored")
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
            if /* rowS.cnn == row.cnn && */
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
    func interceptSearch(near coord: Coordinate, with direction:StreetSide!) -> (RowStreetSweeping, Edge, Coordinate, Double) {

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
            // OR override direction passed in

            let directionNat: StreetSide = (intercep.latitude - coord.latitude) / (b.latitude - a.latitude) > 0 ? .L : .R
            var edirection = directionNat

            if let fdirection = direction {
                edirection  = fdirection
            }

            // if D is > segment length forget it
            if edirection == side &&
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
    // ABx / y
    let ABlat = (b.latitude-a.latitude)
    let ABlng = (b.longitude-a.longitude)

    // if rise is slope lat/lng
    let S = ABlng / ABlat    // 15 / 30 = 0.5

    // U = lat
    // V = lng
    //
    let AClat = (c.latitude-a.latitude)
    let BClat = (c.latitude-b.latitude)
    let AClng = (c.longitude-a.longitude)
    let BClng = (c.longitude-b.longitude)

    // use lat for lng cmponent of intercept (walk along X, then from there walk along Y

    //let u = (AClng / rise + AClat) / 2
    let v = ( AClng - AClat*S )
    let u =  v / (S) + AClat

//    print("""
//    rise=\(rise)
//    v=\(v)
//    u=\(u)
//    """)

    return Coordinate(a.latitude+u, a.longitude+v)
}
