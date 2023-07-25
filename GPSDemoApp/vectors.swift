//
//  vectors.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 7/24/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//
import MapKit

import Foundation


// TODO: better typing e.g.:
typealias Vertex = CLLocationCoordinate2D
typealias Edge = (Vertex, Vertex)

extension Vertex {
    init(_ u: Double, _ v: Double) {
        self.init()
        latitude = u
        longitude = v
    }
}

//var AllVertices: [Vertex] = []
//var AllEdges: [Edge] = []

let dist2: (Double, Double, Double, Double) -> Double = {
    la1, lo1, la2, lo2 in

    return sqrt(
        pow(la2-la1, 2) * pow(lo2-lo1, 2)
    )
}

// distance to nearest point
let VectorDotProduct: (Edge, Vertex) -> Double = {
    row, coord in

    let a = row.0
    let b = row.1
    let c = coord

    // row V
    let lLa = (a.latitude - b.latitude)
    let lLo = (a.longitude - b.longitude)

    // coord U
    let cLa =  (a.latitude - coord.latitude)
    let cLo =  (a.longitude - coord.longitude)

    let rise = (lLa / lLo) // perpendicujlar slope

    var kLa = cLo * rise
    var kLo = kLa / rise

    // TODO: use the dot product to sort
    return dist2(coord.latitude, coord.longitude, a.latitude + kLa, a.longitude + kLo)
}


