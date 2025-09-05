//
//  CLLocation+Equabable.swift
//  Pods
//
//  Created by Justin Brady on 7/21/23.
//

import Foundation
import CoreLocation

extension CLLocationCoordinate2D: Equatable {}

public func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}
