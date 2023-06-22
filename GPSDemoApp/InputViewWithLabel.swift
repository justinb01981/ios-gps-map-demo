//
//  InputViewWithLabel.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 3/8/21.
//  Copyright © 2021 Justin Brady. All rights reserved.
//

import Foundation
import UIKit

typealias TextInputView = UITextView

protocol BaseControlWithLabel: UIView {
    
    var input: UIView { get }
    
    var text: String { get set }
    
    var switchIsOn: Bool { get }
}

class TextViewWithLabel: UIView, BaseControlWithLabel {
    
    var field: TextInputView = TextInputView()
    var input: UIView {
        return field as TextInputView
    }

    var text: String {
        get {
            return (input as? TextInputView)?.text ?? ""
        }

        set {
            (input as? TextInputView)?.text = newValue
        }

    }
    
    var switchIsOn: Bool {
        fatalError("TextViewWithLabel: switchIsOn called on text field")
    }
    
    init(label text: String) {
        super.init(frame: CGRect.zero)
        
        let topView = self
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        
        let label = UILabel()
        label.text = text
        
        stackView.addArrangedSubview(label)
        
        field.frame = CGRect(x: 8, y: 8, width: 120, height: 32)
        field.layer.borderWidth = 1.0
        field.layer.borderColor = UIColor.white.cgColor
        
        stackView.addArrangedSubview(input)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        topView.addSubview(stackView)
        
        topView.addConstraints([
            topView.topAnchor.constraint(equalTo: stackView.topAnchor),
            topView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
            topView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            topView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            // height constraint
            topView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    required init(coder: NSCoder) {
        fatalError("not implemented")
    }
    
    override func resignFirstResponder() -> Bool {
        input.resignFirstResponder()
    }
}

class SwitchViewWithLabel: TextViewWithLabel {
    
    let inputSwitch = UISwitch()
    
    override var input: UIView {
        return inputSwitch
    }
    
    override init(label text: String) {
        super.init(label: text)
        
        if let stack = subviews.first as? UIStackView {
            stack.insertSubview(inputSwitch, at: 0)
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var switchIsOn: Bool {
        if let s = self.input as? UISwitch {
            return s.isOn
        }
        fatalError()
    }
}
