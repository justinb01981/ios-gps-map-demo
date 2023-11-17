//
//  CalendarMgr.swift
//  Pods
//
//  Created by Justin Brady on 9/6/23.
//

import Foundation
import EventKit

fileprivate let DURATION = 15.0

var gCalendarMgr = CalendarMgr()    // singleton

class CalendarMgr {
    let stor: EKEventStore

    init() {
        stor = EKEventStore(
        )
        stor.requestAccess(to: .event) {
            ok, err in
            if !ok, let err = err {
                print("access requested / failed: ok:\(ok) error:\(err)")
                return
            }
            print("access requested / success")
        }
    }

    var userCalendar: Calendar {
        get {
            return Calendar.current
        }
    }

    func createReminderForRow(_ row: RowStreetSweeping, thenCall onComplete: (EKEvent?)->(Void)) {
        let ev = EKEvent(eventStore: stor)

        let dE = row.timeExpireOnLocal()

        ev.startDate = dE //- 30.0
        ev.endDate = dE + DURATION  // duration hack
        ev.calendar = stor.defaultCalendarForNewEvents
        ev.title = "Move car for street-cleaning @ \(row.name) (\(row.scheduleText())"

        // TODO: add location to event?
//        ev.location = // location under the cursor?

        //commmit to cal
        do {
            try stor.save(ev, span: .thisEvent)

            print("calendar event stored")
            onComplete(ev)
        }
        catch {
            print("calendar event failed to save")
            onComplete(nil)
        }

    }

    
}

