//
//  DotAnnotationView.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 7/10/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//

import Foundation
import MapKit



class DotAnnotationView: MKAnnotationView {
    static let kDotAnnotationName = "dot"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        self.image = UIImage(named: DotAnnotationView.kDotAnnotationName)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
