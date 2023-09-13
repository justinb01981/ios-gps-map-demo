//
//  ViewController.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/5/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import UIKit
import MapKit
import EventKit

class ViewController: UIViewController {
    
    private var viewModel = ViewModel()
    private var mapUI: MKMapView!
    private var streetView: BaseControlWithLabel = TextViewWithLabel(label: "Street")
    private var scheduleView: BaseControlWithLabel = TextViewWithLabel(label: "Schedule")
    private var pathOverlay, debugOverlay, edgeOverlay: MKOverlay!
    private var pathOverlaySide: StreetSide!

    private let pad = 2.0
    private let altitude = 1000.0

    @IBOutlet private var controlsView: ControlsView!

    private var sweepingManager: StreetSweepMgr!

    lazy private var remindButton: BaseControlWithLabel = ButtonViewWithLabel(named: "Reminder", withAction: {
        // TODO: set reminder

        /*
         see rfc 2445
         */

        // use viewModel remindtarget
        if let fr = self.viewModel.foundRow {

            gCalendarMgr.createReminderForRow(fr) {
                // onCreate closure
                (evOpt) in
                let a: UIAlertController
                let adjustDate = DateFormatter()
                adjustDate.dateFormat = "MM/dd"

                if let ev = evOpt {
                    let str = adjustDate.string(from: ev.startDate!)
                    a = UIAlertController(title: "success", message: "event created on \(str)", preferredStyle: .alert)
                }
                else {
                    a = UIAlertController(title: "success", message: "event creation failed\n(probably calendar permission settings)", preferredStyle: .alert)
                }

                let act = UIAlertAction(title: "OK", style: .default) { alerT in
                    // dismiss
                    a.dismiss(animated: true)
                }
                a.addAction(act)

                self.present(a, animated: true)
            }
        }
    })

    lazy private var recenterButton: BaseControlWithLabel = ButtonViewWithLabel(named: "Re-center", withAction: {
        if let loc = self.viewModel.sweepLocation() {
            self.mapUI.centerCoordinate = loc
        }
        self.centeredAtStart = false
    })

    var r: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        viewModel.delegate = self
        
        // set up map view inside our view
        mapUI = MKMapView()
        mapUI.translatesAutoresizingMaskIntoConstraints = false
        mapUI.delegate = self

        DotAnnotationView.registerWithMap(mapUI)
        CursorAnnotationView.registerWithMap(mapUI)

        view.addSubview(mapUI)
        view.addSubview(controlsView)
        view.addConstraints([
            view.topAnchor.constraint(equalTo: mapUI.topAnchor),
            view.bottomAnchor.constraint(equalTo: mapUI.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: mapUI.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mapUI.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: controlsView.bottomAnchor),
            controlsView.heightAnchor.constraint(equalToConstant: streetView.height + scheduleView.height + pad)
        ])

        // controlsView

        controlsView.verticalListAdd(streetView)
        controlsView.verticalListAdd(scheduleView)
        controlsView.verticalListAdd(remindButton)
        controlsView.verticalListAdd(recenterButton)

        controlsView.alpha = 0.75
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        sweepingManager = StreetSweepMgr(city: Settings.shared.city)
        MyLocationManager.shared.restart()
    }

    @objc func clearLog() {
        LocationLog.shared.flush()
        mapUI.removeAnnotations(mapUI.annotations)
    }

    @objc func mapTouched(_ touches: NSSet, _ event: UIEvent) {
        //print("touch event \(event) \(touches)")
    }

    var centeredAtStart = false

    var newMarker: MKPointAnnotation! // represents gps
    var newMarkerCenter: MKPointAnnotation! // represents cursor

    var overlayHackStrokeBothsides = false

}

extension ViewController: ViewModelDelegate {
    func targetLocation() -> Coordinate {
        mapUI.camera.centerCoordinate
    }

    func replaceTarget(_ c: Coordinate) {
        mapUI.camera.centerCoordinate = c
    }

    func updatedMyLocation(_ tailCoord: Coordinate) {

        print("updatedMyLocation: \(tailCoord)")

        if !centeredAtStart {
            mapUI.camera.centerCoordinate = tailCoord
            mapUI.camera.altitude = altitude
            centeredAtStart = true
        }

        if let annotGps = mapUI.dequeueReusableAnnotationView(withIdentifier: gpsAnnotationViewName)
        {
            if let old = newMarker {
                mapUI.removeAnnotation(old)
            }

            newMarker = MKPointAnnotation()
            annotGps.annotation = newMarker
            newMarker.coordinate = tailCoord
            newMarker.title = gpsAnnotationViewName

            // TODO: move some to viewmodel
            mapUI.addAnnotation(newMarker) // repeat it anyway
        }
    }

    func updateSchedule(_ tailCoord: Coordinate) {

        viewModel.sweepScheduleSearch(tailCoord) {

            [unowned self] srow in

            guard let srow = srow, srow.line.count > 0 else {
                fatalError("sweep schedule search no row or empty-line row found")
            }

            // remove previous drawing
            if let removeOver = pathOverlay {
                streetView.text = "???"
                scheduleView.text = "???"
                mapUI.removeOverlay(removeOver)
                pathOverlay = nil
            }

            streetView.text = srow.streetText()
            scheduleView.text = srow.scheduleText() //"\(srow.schedText) (\(srow.timeRemain)"

            let polyline = srow.fullRouteCoordinates()

            //overlayHackStrokeBothsides = srow.sideOppositeRow != nil // dumb coloring hack

            pathOverlay = MKPolyline(coordinates: polyline, count: polyline.count)
            pathOverlaySide = srow.side
            mapUI.addOverlay(pathOverlay)

            if let intCoord = viewModel.matchedIntercept {
                if let prevOv = debugOverlay {
                    mapUI.removeOverlay(prevOv)
                }
                debugOverlay = MKPolyline(coordinates: [intCoord, tailCoord], count: 2)
                mapUI.addOverlay(debugOverlay)
            }

            if let intEdge = viewModel.matchedEdge {
                let c = [intEdge.0, intEdge.1]
                if edgeOverlay != nil {
                    mapUI.removeOverlay(edgeOverlay)
                }
                edgeOverlay = MKPolyline(coordinates:c , count: c.count)
                mapUI.addOverlay(edgeOverlay)
            }
        }

        if let annotGps = mapUI.dequeueReusableAnnotationView(withIdentifier: CursorAnnotationViewName)
        {
            if let old = newMarkerCenter { mapUI.removeAnnotation(old) }

            newMarkerCenter = MKPointAnnotation()
            annotGps.annotation = newMarkerCenter
            newMarkerCenter.coordinate = mapUI.centerCoordinate
            newMarkerCenter.title = CursorAnnotationViewName

            // TODO: move some to viewmodel
            mapUI.addAnnotation(newMarkerCenter) // repeat it anyway
        }
    }
}

extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotView = mapUI.dequeueReusableAnnotationView(withIdentifier: annotation.title!!)
        return annotView
    }

    func mapView(
        _ mapView: MKMapView,
        rendererFor overlay: MKOverlay
    ) -> MKOverlayRenderer {

        guard let overlay = overlay as? MKPolyline
        else {
            fatalError()
        }

        let overRenderer = MKPolylineRenderer(overlay: overlay)
        if overlay.isEqual(debugOverlay) {
            overRenderer.strokeColor = UIColor.cyan
        }
        else if overlay.isEqual(edgeOverlay) {
            overRenderer.strokeColor = UIColor.yellow
        }
        else {
            overRenderer.strokeColor = pathOverlaySide == .R ? UIColor.blue : UIColor.green
        }

        // preserve prior overlay
        if overlayHackStrokeBothsides {
//            overRenderer.strokeColor = UIColor.purple
        }
        else {

        }
        // TODO: hilite both sides of the street and both sweep schedules indicated by color?
        overRenderer.lineWidth = 4.0

        return overRenderer

    }
}
