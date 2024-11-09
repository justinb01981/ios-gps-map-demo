//
//  ViewController.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/5/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import UIKit
import MapKit
//import EventKit

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

    var centeredAtStart = false

    var newMarker: MKPointAnnotation! // represents gps
    var newMarkerCenter: MKPointAnnotation! // represents cursor

    var overlayHackStrokeBothsides = false

    lazy private var remindButton: BaseControlWithLabel = ButtonViewWithLabel(named: "Reminder", withAction: {
        [unowned self] in
        /*
         see rfc 2445
         */

        // use viewModel remindtarget
        guard let lastRow = viewModel.lastSearchResult?.row else { return }

        viewModel.createReminder(lastRow) {
            [unowned self] (evOpt) in

            let a: UIAlertController

            if let ev = evOpt {
                let adjustDate = DateFormatter()
                adjustDate.dateFormat = "MM/dd"

                let str = adjustDate.string(from: ev.startDate!)
                a = UIAlertController(title: "success", message: "event created on \(str)", preferredStyle: .alert)
            }
            else {
                a = UIAlertController(title: "error", message: "event creation failed\n(probably calendar permission settings)", preferredStyle: .alert)
            }

            let act = UIAlertAction(title: "OK", style: .default) { alerT in
                // dismiss
                a.dismiss(animated: true)
            }

            a.addAction(act)

            present(a, animated: true)
        }
        
    })

    lazy private var recenterButton: BaseControlWithLabel = ButtonViewWithLabel(named: "Re-center", withAction: {
        if let loc = self.viewModel.sweepLocation() {
            self.mapUI.centerCoordinate = loc
        }
        self.centeredAtStart = false
    })

    lazy private var swapButton: BaseControlWithLabel = ButtonViewWithLabel(named: "swap left/right") {

        self.viewModel.swapStreetSide(then: {
            print("\($0)")
            self.viewModel.refreshFromCursor()
        })
    }

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
            view.trailingAnchor.constraint(equalTo: mapUI.trailingAnchor)
        ])

        // controlsView

        controlsView.verticalListAdd(streetView)
        controlsView.verticalListAdd(scheduleView)
        controlsView.verticalListAdd(remindButton)
        controlsView.verticalListAdd(recenterButton)
        controlsView.verticalListAdd(swapButton)

        controlsView.alpha = 0.90
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        sweepingManager = StreetSweepMgr(city: Settings.shared.city)
        MyLocationManager.shared.restart()

        pollCursor()
    }

    func viewDidAppear() {
        if viewModel.delegate == nil { fatalError() }
    }

    @objc func clearLog() {
        LocationLog.shared.flush()
        mapUI.removeAnnotations(mapUI.annotations)
    }

    @objc func mapTouched(_ touches: NSSet, _ event: UIEvent) {
        //print("touch event \(event) \(touches)")
    }


    private var pollCursorLast = CLLocationCoordinate2D()

    private func pollCursor() {

        let c = self.mapUI.centerCoordinate

        DispatchQueue(label: "pollCursor").asyncAfter(deadline: .now()+0.1) {
            [weak self] in

            if c != self?.pollCursorLast {
                self?.pollCursorLast = c
                self?.viewModel.refreshFromCursor()
            }

            self?.pollCursor()
        }
    }

}

extension ViewController: ViewModelDelegate {
    func targetLocation() -> Coordinate {
        mapUI.camera.centerCoordinate
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

    private func renderRow(_ srow: RowStreetSweeping) {

        guard srow.line.count > 0 else {
            //                print("sweep schedule search no row or empty-line row found")
            return
        }

        // remove previous drawing
        if let removeOver = pathOverlay {
            streetView.text = "???"
            scheduleView.text = "???"
            mapUI.removeOverlay(removeOver)
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
            debugOverlay = MKPolyline(coordinates: [intCoord, /*tailCoord*/ mapUI.centerCoordinate], count: 2)
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

    func updateSchedule(_ tailCoord: Coordinate) {

        viewModel.sweepScheduleSearch(tailCoord) {
            [weak self] srow in

            let srow = srow!
            DispatchQueue.main.async {
                self?.renderRow(srow)
            }
        }

        DispatchQueue.main.async {
            [unowned self] in

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
}

extension ViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        viewModel.refreshFromCursor()
    }
    
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
