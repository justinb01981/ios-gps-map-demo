//
//  DotAnnotationView.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 7/10/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//

import Foundation
import MapKit




let gpsAnnotationViewName = "dot"
class DotAnnotationView: MKAnnotationView {

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        self.image = UIImage(named: gpsAnnotationViewName)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    class func registerWithMap(_ mapUI: MKMapView) {
        mapUI.register(self.self, forAnnotationViewWithReuseIdentifier: gpsAnnotationViewName)
    }
}

let CursorAnnotationViewName = "cursor"
class CursorAnnotationView: DotAnnotationView {

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        self.image = UIImage(named: CursorAnnotationViewName)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class func registerWithMap(_ mapUI: MKMapView) {
        mapUI.register(self.self, forAnnotationViewWithReuseIdentifier: CursorAnnotationViewName)
    }

}
