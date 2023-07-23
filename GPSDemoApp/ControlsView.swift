//
//  ControlsView.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 7/10/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//

import Foundation
import UIKit

class ControlsView: UIView {
    var topToBottom: [BaseControlWithLabel] = []
    let space = 4.0

    override func layoutSubviews() {
        // experimenting this is jank
        var span = 0.0
        for cur in topToBottom {
            let h = cur.height

            let mcur = cur
            mcur.frame = CGRect(x: space*2, y: span, width: self.frame.width-space*2, height: h)
            
            span += cur.height + space
        }
    }

    func verticalListAdd(_ view: BaseControlWithLabel) {
        topToBottom += [view]
        var top = 0.0
        if let topSub = subviews.sorted(by: { $0.frame.maxY < $1.frame.maxY }).first {
            top = topSub.frame.maxY
        }

        view.frame = CGRect(x: 0, y: top, width: view.frame.width, height: view.frame.height)

        addSubview(view)
    }
}
