//
//  TextViewWithLabel.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/8/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import Foundation
import UIKit

class TextViewWithLabel: UIView {
    
    var label: UILabel!
    var input: UITextField!
    
    static func createField(named: String) -> TextViewWithLabel {
        let topView = TextViewWithLabel()
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        
        let label = UILabel()
        label.text = "\(named):"
        
        stackView.addArrangedSubview(label)
        
        let input = UITextField()
        stackView.addArrangedSubview(input)
        input.placeholder = named
        input.textAlignment = .left
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        topView.addSubview(stackView)
        
        topView.addConstraints([
            topView.topAnchor.constraint(equalTo: stackView.topAnchor),
            topView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
            topView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            topView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            // height constraint
            topView.heightAnchor.constraint(equalToConstant: 64)
        ])
        
        topView.backgroundColor = UIColor.red
        
        topView.label = label
        topView.input = input
        return topView
    }
}
