//
//  UserLicensing.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 11/15/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//

import Foundation

class UserLicensing {

    func isLicensed(forLocation loc: Vertex) -> Bool {
        return true
    }

    static var shared = UserLicensing()
}
