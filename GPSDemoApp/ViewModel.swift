//
//  ViewModel.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/5/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import Foundation
import UIKit

protocol ViewModelDelegate: NSObject {
    func update()
}

class ViewModel: NSObject {
    weak var delegate: ViewModelDelegate!
    
    static let kLocationLogKey = "loggedLocations"
    
    var allLocations: [LocationLogEntry] {
        get {
            return LocationLog.shared.all
        }
    }
    
    var distance: Double = Settings.shared.distance {
        didSet {
            Settings.shared.distance = distance
            self.delegate?.update()
            MyLocationManager.shared.restart()
        }
    }
    var accuracy: Double = Settings.shared.accuracy {
        didSet {
            Settings.shared.accuracy = accuracy
            self.delegate?.update()
            MyLocationManager.shared.restart()
        }
    }
    
    override init() {
        super.init()
        
        MyLocationManager.shared.startObserving { (location) in
            
            self.delegate?.update()
        }
    }
    
    deinit {
        MyLocationManager.shared.stopObserving()
    }
}
