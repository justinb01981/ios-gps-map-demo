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
    private var pathOverlay: MKOverlay!
    private var pathOverlaySide: StreetSide!

    private let pad = 2.0
    private let altitude = 1000.0

    @IBOutlet private var controlsView: ControlsView!

    private var sweepingManager: StreetSweepMgr!

    lazy private var remindButton: BaseControlWithLabel = ButtonViewWithLabel(named: "Reminder", withAction: {
        // TODO: set reminder
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
        mapUI.register(DotAnnotationView.self, forAnnotationViewWithReuseIdentifier: DotAnnotationView.kDotAnnotationName)

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

    let newMarker = MKPointAnnotation()
    let newMarkerCenter = MKPointAnnotation()

    let myAnnotationsByName: [String: MKAnnotation] = [:]

    var overlayHackStrokeBothsides = false

}

extension ViewController: ViewModelDelegate {
    func targetLocation() -> CLLocationCoordinate2D {
        mapUI.camera.centerCoordinate
    }

    func replaceTarget(_ c: CLLocationCoordinate2D) {
        mapUI.camera.centerCoordinate = c
    }

    func updatedMyLocation(_ tailCoord: CLLocationCoordinate2D) {

        print("updatedMyLocation: \(tailCoord)")

        if !centeredAtStart {
            mapUI.camera.centerCoordinate = tailCoord
            mapUI.camera.altitude = altitude
            centeredAtStart = true
        }

        if let annotGps = mapUI.dequeueReusableAnnotationView(withIdentifier: DotAnnotationView.kDotAnnotationName)
        {
            annotGps.annotation = newMarker
            newMarker.coordinate = tailCoord
            newMarker.title = "👩"

            // TODO: move some to viewmodel
            mapUI.addAnnotation(newMarker) // repeat it anyway
        }

        if let annotGps = mapUI.dequeueReusableAnnotationView(withIdentifier: DotAnnotationView.kDotAnnotationName)
        {
            annotGps.annotation = newMarkerCenter
            newMarkerCenter.coordinate = mapUI.centerCoordinate
            newMarkerCenter.title = "👩"

            // TODO: move some to viewmodel
            mapUI.addAnnotation(newMarkerCenter) // repeat it anyway
        }
    }

    func updateSchedule(_ tailCoord: CLLocationCoordinate2D) {
        viewModel.sweepScheduleSearch(tailCoord) {
            [unowned self] foundRow in
            guard let srow = foundRow else { return }

            if srow.line.count == 0 {
                // nothing matched - leave polyline for now
                return
            }

            streetView.text = srow.streetText()
            scheduleView.text = srow.scheduleText() //"\(srow.schedText) (\(srow.timeRemain)"

            let polyline = StreetSweepMgr.shared.fullRouteCoordinates(srow)

            if let removeOver = pathOverlay {
                mapUI.removeOverlay(removeOver)
            }
            overlayHackStrokeBothsides = srow.sideOppositeRow != nil // dumb coloring hack

            pathOverlay = MKPolyline(coordinates: polyline, count: polyline.count)
            pathOverlaySide = srow.side

            mapUI.addOverlay(pathOverlay)
        }
    }
}

extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotView = mapUI.dequeueReusableAnnotationView(withIdentifier: DotAnnotationView.kDotAnnotationName)
        return annotView
    }

    func mapView(
        _ mapView: MKMapView,
        rendererFor overlay: MKOverlay
    ) -> MKOverlayRenderer {

        guard let overlay = overlay as? MKPolyline
        else {
            fatalError("only mkpolyline handled")
        }

        let overRenderer = MKPolylineRenderer(overlay: overlay)

        overRenderer.strokeColor = pathOverlaySide == .R ? UIColor.blue : UIColor.green

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
