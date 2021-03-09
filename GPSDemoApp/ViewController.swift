//
//  ViewController.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/5/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import UIKit
import MapKit

fileprivate let kDotAnnotationName = "dot"

class ViewController: UIViewController {
    
    class DotAnnotationView: MKAnnotationView {
        override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
            super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
            
            self.image = UIImage(named: kDotAnnotationName)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var viewModel = ViewModel()
    private var mapUI: MKMapView!
    private var settingsView: UIView!
    private var settingsViewDistance: BaseControlWithLabel!
    private var settingsViewAccuracy: BaseControlWithLabel!
    private var settingsViewClearLog: BaseControlWithLabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        viewModel.delegate = self
        
        // set up map view inside our view
        mapUI = MKMapView()
        mapUI.translatesAutoresizingMaskIntoConstraints = false
        mapUI.delegate = self
        
        mapUI.register(DotAnnotationView.self, forAnnotationViewWithReuseIdentifier: kDotAnnotationName)

        view.addSubview(mapUI)
        view.addConstraints([
            view.topAnchor.constraint(equalTo: mapUI.topAnchor),
            view.bottomAnchor.constraint(equalTo: mapUI.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: mapUI.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mapUI.trailingAnchor)
        ])

        // set up settings view in our view
        settingsView = UIView()
        settingsView.backgroundColor = UIColor.gray
        settingsView.layer.cornerRadius = 8.0
        settingsViewDistance = TextViewWithLabel.createField(named: "distance(m)")
        settingsViewAccuracy = TextViewWithLabel.createField(named: "accuracy(m)")
        settingsViewClearLog = SwitchViewWithLabel.createField(named: "reset log")
        
        // TODO -- add reset (clear log) button
        
        let closeButton = UIButton()
        closeButton.setTitle("OK", for: .normal)
        closeButton.addTarget(self, action: #selector(toggleSettings), for: .touchUpInside)
        
        let openButton = UIButton()
        openButton.setTitle("⚙", for: .normal)
        openButton.titleLabel?.textColor = UIColor.blue
        openButton.addTarget(self, action: #selector(toggleSettings), for: .touchUpInside)
        
        for view in [settingsView, settingsViewDistance, settingsViewAccuracy, settingsViewClearLog, closeButton, openButton] {
            view?.translatesAutoresizingMaskIntoConstraints = false
        }
        
        settingsView.addSubview(closeButton)
        settingsView.addSubview(settingsViewDistance)
        settingsView.addSubview(settingsViewAccuracy)
        settingsView.addSubview(settingsViewClearLog)
        view.addSubview(settingsView)
        view.addSubview(openButton)
        view.bringSubviewToFront(settingsView)

        settingsView.addConstraints([
            // vertical constraints
            settingsView.topAnchor.constraint(equalTo: settingsViewDistance.topAnchor),
            settingsViewDistance.bottomAnchor.constraint(equalTo: settingsViewAccuracy.topAnchor),
            settingsViewAccuracy.bottomAnchor.constraint(equalTo: settingsViewClearLog.topAnchor),
            settingsViewClearLog.bottomAnchor.constraint(equalTo: closeButton.topAnchor),
            settingsView.bottomAnchor.constraint(equalTo: closeButton.bottomAnchor),
            // horizontal constraints
            settingsView.leadingAnchor.constraint(equalTo: settingsViewAccuracy.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: settingsViewAccuracy.trailingAnchor),
            settingsView.leadingAnchor.constraint(equalTo: settingsViewDistance.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: settingsViewDistance.trailingAnchor),
            settingsView.leadingAnchor.constraint(equalTo: settingsViewClearLog.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: settingsViewClearLog.trailingAnchor),
            settingsView.leadingAnchor.constraint(equalTo: closeButton.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: closeButton.trailingAnchor),
        ])

        // constraints in view for settingsView child
        view.addConstraints([
            settingsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsView.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
            settingsView.bottomAnchor.constraint(equalTo: view.topAnchor, constant: 250),
        ])
        
        // constraints in view for openButton
        view.addConstraints([
            view.trailingAnchor.constraint(equalTo: openButton.trailingAnchor),
            view.topAnchor.constraint(equalTo: openButton.topAnchor, constant: -50),
            view.trailingAnchor.constraint(equalTo: openButton.leadingAnchor, constant: 100),
            view.topAnchor.constraint(equalTo: openButton.bottomAnchor, constant: -100)
        ])
    }

    @objc func toggleSettings() {
        guard let t1d = Double(settingsViewAccuracy.text),
            let t2d = Double(settingsViewDistance.text)
            else {
                return
        }
        
        settingsView.isHidden = !settingsView.isHidden
        _ = settingsViewDistance.resignFirstResponder()
        _ = settingsViewAccuracy.resignFirstResponder()

        viewModel.accuracy = t1d
        viewModel.distance = t2d
        
        if settingsViewClearLog.switchIsOn {
            LocationLog.shared.flush()
            mapUI.removeAnnotations(mapUI.annotations)
        }
        
        MyLocationManager.shared.restart()
    }
}

extension ViewController: ViewModelDelegate {
    func update() {
        
        for entry in viewModel.allLocations[viewModel.allLocations.index(0, offsetBy: 1) ..< viewModel.allLocations.endIndex] {
            
            if let annot = mapUI.dequeueReusableAnnotationView(withIdentifier: kDotAnnotationName) {
                let newMarker = MKPointAnnotation()
                annot.annotation = newMarker
                newMarker.coordinate = CLLocationCoordinate2D(latitude: entry.lat, longitude: entry.long)
                newMarker.title = "\(entry.time ?? Date())"

                mapUI.addAnnotation(newMarker)
            }
        }
        
        // center camera over this new location
        if let zoomLoc = viewModel.allLocations.last {
            mapUI.camera.altitude = 1000
            mapUI.camera.centerCoordinate = CLLocationCoordinate2D(latitude: zoomLoc.lat, longitude: zoomLoc.long)
        }
    }
}

extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotView = mapUI.dequeueReusableAnnotationView(withIdentifier: kDotAnnotationName)
        return annotView
    }
}
