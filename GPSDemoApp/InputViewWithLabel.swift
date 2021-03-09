//
//  InputViewWithLabel.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/8/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import Foundation
import UIKit

class BaseControlWithLabel: UIView {
    
    var input: UIView!
    
    var text: String {
        get {
            fatalError()
        }
    }
    
    var switchIsOn: Bool {
        fatalError()
    }
    
    override func resignFirstResponder() -> Bool {
        return input.resignFirstResponder()
    }
}

class TextViewWithLabel: BaseControlWithLabel {
    
    private var label: UILabel!
    
    override var text: String {
        get {
            return (input as! UITextField).text ?? ""
        }
    }
    
    static func createField(named: String) -> BaseControlWithLabel {
        let topView = self.self.init()
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        
        let label = UILabel()
        label.text = "\(named):"
        
        stackView.addArrangedSubview(label)
        
        let input = topView.inputElement()
        input.layer.borderWidth = 2.0
        input.layer.cornerRadius = 8.0
        input.layer.borderColor = UIColor.black.cgColor
        
        stackView.addArrangedSubview(input)
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
        
        topView.label = label
        topView.input = input
        return topView
    }
    
    internal func inputElement() -> UIView {
        let input = UITextField()
        
        return input
    }
}

class SwitchViewWithLabel: TextViewWithLabel {
    
    override internal func inputElement() -> UIView {
        let s = UISwitch()
        s.isOn = false
        return s
    }
    
    override var switchIsOn: Bool {
        if let s = self.input as? UISwitch {
            return s.isOn
        }
        fatalError()
    }
}
