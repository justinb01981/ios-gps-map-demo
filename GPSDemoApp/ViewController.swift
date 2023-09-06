//
//  ViewController.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/5/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController {
    
    private var viewModel = ViewModel()
    private var mapUI: MKMapView!
    private var streetView: BaseControlWithLabel = TextViewWithLabel(label: "Street")
    private var scheduleView: BaseControlWithLabel = TextViewWithLabel(label: "Schedule")
    private var pathOverlay, debugOverlay: MKOverlay!
    private var pathOverlaySide: StreetSide!

    private let pad = 2.0
    private let altitude = 1000.0

    private var remindTarget: Date!

    @IBOutlet private var controlsView: ControlsView!

    private var sweepingManager: StreetSweepMgr!

    lazy private var remindButton: BaseControlWithLabel = ButtonViewWithLabel(named: "Reminder", withAction: {
        // TODO: set reminder
        let df = DateFormatter()
        df.dateFormat = "YYYYMMDDhhmmss"
        print("\((df.string(from: self.remindTarget)))")
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

            [unowned self] foundRow in

            if let removeOver = pathOverlay {
                streetView.text = "???"
                scheduleView.text = "???"
                mapUI.removeOverlay(removeOver)
            }

            guard let srow = foundRow else {
                return

            }

            if srow.line.count == 0 {
                return
            }

            remindTarget = srow.timeExpire
            streetView.text = srow.streetText()
            scheduleView.text = srow.scheduleText() //"\(srow.schedText) (\(srow.timeRemain)"


//            if let polyline = StreetSweepMgr.shared.fullRouteCoordinates(srow) as [Coordinate]?
            let polyline = srow.fullRouteCoordinates()

            //overlayHackStrokeBothsides = srow.sideOppositeRow != nil // dumb coloring hack

            pathOverlay = MKPolyline(coordinates: polyline, count: polyline.count)
            pathOverlaySide = srow.side

            mapUI.addOverlay(pathOverlay)

            if let prevOv = debugOverlay {
                mapUI.removeOverlay(prevOv)
                debugOverlay = nil
            }

            if let intCoord = viewModel.matchedIntercept {
                debugOverlay = MKPolyline(coordinates: [intCoord, tailCoord], count: 2)
                mapUI.addOverlay(debugOverlay)
            }
            else
            {
                if let intEdge = viewModel.matchedEdge {
                    let c = [intEdge.0, intEdge.1]
                    debugOverlay = MKPolyline(coordinates:c , count: c.count)
                    mapUI.addOverlay(debugOverlay)
                }
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
