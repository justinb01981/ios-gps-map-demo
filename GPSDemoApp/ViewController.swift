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
    
    class DotAnnotationView: MKAnnotationView {
        override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
            super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
            
            self.image = UIImage(named: "dot")
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var viewModel = ViewModel()
    private var mapUI: MKMapView!
    
    private var lines: [MKPolyline] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        viewModel.delegate = self
        
        mapUI = MKMapView()
        mapUI.translatesAutoresizingMaskIntoConstraints = false
        mapUI.delegate = self
        
        mapUI.register(DotAnnotationView.self, forAnnotationViewWithReuseIdentifier: "dot")
        
        view.addSubview(mapUI)
        view.addConstraints([
            view.topAnchor.constraint(equalTo: mapUI.topAnchor),
            view.bottomAnchor.constraint(equalTo: mapUI.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: mapUI.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mapUI.trailingAnchor)
        ])
    }
}

extension ViewController: ViewModelDelegate {
    func update() {
        
        guard let p0 = viewModel.allLocations.first else {
            return
        }
        
        for entry in viewModel.allLocations[viewModel.allLocations.index(0, offsetBy: 1) ..< viewModel.allLocations.endIndex] {
            
            if let annot = mapUI.dequeueReusableAnnotationView(withIdentifier: "dot") {
                let newMarker = MKPointAnnotation()
                annot.annotation = newMarker
                newMarker.coordinate = CLLocationCoordinate2D(latitude: entry.lat, longitude: entry.long)
                newMarker.title = "\(entry.time ?? Date())"

                mapUI.addAnnotation(newMarker)
            }
        }
    }
}

extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotView = mapUI.dequeueReusableAnnotationView(withIdentifier: "dot")
        return annotView
    }
}
