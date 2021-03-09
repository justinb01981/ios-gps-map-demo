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
    private var settingsViewDistance: TextViewWithLabel!
    private var settingsViewAccuracy: TextViewWithLabel!
    
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
        settingsView.backgroundColor = UIColor.lightGray
        settingsViewDistance = TextViewWithLabel.createField(named: "distance")
        settingsViewAccuracy = TextViewWithLabel.createField(named: "accuracy")
        
        // TODO -- add reset (clear log) button
        
        let closeButton = UIButton()
        closeButton.setTitle("OK", for: .normal)
        closeButton.addTarget(self, action: #selector(toggleSettings), for: .touchUpInside)
        
        for view in [settingsView, settingsViewDistance, settingsViewAccuracy, closeButton] {
            view?.translatesAutoresizingMaskIntoConstraints = false
        }
        
        settingsView.addSubview(closeButton)
        settingsView.addSubview(settingsViewDistance)
        settingsView.addSubview(settingsViewAccuracy)
        view.addSubview(settingsView)

        settingsView.addConstraints([
            // vertical constraints
            settingsView.topAnchor.constraint(equalTo: settingsViewDistance.topAnchor),
            settingsViewDistance.bottomAnchor.constraint(equalTo: settingsViewAccuracy.topAnchor),
            settingsViewAccuracy.bottomAnchor.constraint(equalTo: closeButton.topAnchor),
            settingsView.bottomAnchor.constraint(equalTo: closeButton.bottomAnchor),
            // horizontal constraints
            settingsView.leadingAnchor.constraint(equalTo: settingsViewAccuracy.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: settingsViewAccuracy.trailingAnchor),
            settingsView.leadingAnchor.constraint(equalTo: settingsViewDistance.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: settingsViewDistance.trailingAnchor),
            settingsView.leadingAnchor.constraint(equalTo: closeButton.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: closeButton.trailingAnchor),
        ])

        // constraints in view for settingsView child
        view.addConstraints([
            settingsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsView.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
            settingsView.bottomAnchor.constraint(equalTo: view.topAnchor, constant: 250)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    @objc func toggleSettings() {
        guard let t1 = settingsViewAccuracy.input,
            let t1d = Double(t1.text!),
            let t2 = settingsViewDistance.input,
            let t2d = Double(t2.text!)
            else {
                return
        }
        
        settingsView.isHidden = !settingsView.isHidden
        settingsViewDistance.input.resignFirstResponder()
        settingsViewAccuracy.input.resignFirstResponder()

        Settings.shared.accuracy = t1d
        Settings.shared.distance = t2d
        
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
