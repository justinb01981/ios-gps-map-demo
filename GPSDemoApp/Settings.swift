//
//  Settings.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/8/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import Foundation


fileprivate let kAccuracy = "accuracy"
fileprivate let kDistance = "distinterval"

class Settings: NSObject {
    static var shared = Settings()
    
    var accuracy: Double {
        get {
            if UserDefaults.standard.value(forKey: kAccuracy) == nil {
                UserDefaults.standard.set(1.0, forKey: kAccuracy)
            }
            return UserDefaults.standard.double(forKey: kAccuracy)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: kAccuracy)
        }
    }
    
    var distance: Double {
        get {
            if UserDefaults.standard.value(forKey: kDistance) == nil {
                UserDefaults.standard.set(1.0, forKey: kDistance)
            }
            return UserDefaults.standard.double(forKey: kDistance)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: kDistance)
        }
    }

    var city: String = "sf"
}
