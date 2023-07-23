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
    
    var field: UITextView { get }
    
    var text: String { get set }
    
    var switchIsOn: Bool { get }

    var height: Double { get }
}

class TextViewWithLabel: UIView, BaseControlWithLabel {

    var labelWidth = 128.0
    var height = 48.0
    var fieldT: UITextView = TextInputView()
    var field: TextInputView {
        return fieldT
    }

    var text: String {
        get {
            return fieldT.text
        }

        set {
            fieldT.text = newValue
        }

    }
    
    var switchIsOn: Bool {
        fatalError("TextViewWithLabel: switchIsOn called on text field")
    }

    init(label text: String) {

        super.init(frame: CGRect.infinite)

        self.layer.borderColor = UIColor.gray.cgColor
        self.layer.borderWidth = 2.0
        //self.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = text
        label.textAlignment = .center

        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        field.layer.borderWidth = 1.0
        field.layer.borderColor = UIColor.gray.cgColor
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isUserInteractionEnabled = false // read only for now
        addSubview(field)

        addConstraints([
            field.topAnchor.constraint(equalTo: topAnchor),
            field.bottomAnchor.constraint(equalTo: bottomAnchor),
            field.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 16.0),
            field.trailingAnchor.constraint(equalTo: trailingAnchor),
            // height constraint

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16.0),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 64)
        ])
    }
    
    required init(coder: NSCoder) {
        fatalError("not implemented")
    }
    
    override func resignFirstResponder() -> Bool {
        field.resignFirstResponder()
    }
}

class SwitchViewWithLabel: TextViewWithLabel {
    
    let inputSwitch = UISwitch()
    
    override init(label text: String) {
        super.init(label: text)

        addSubview(inputSwitch)
        bringSubviewToFront(inputSwitch)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var switchIsOn: Bool {
        fatalError("switch unfinished")
    }
}

//
class ButtonViewWithLabel: TextViewWithLabel {

    class actionHandler: UIButton
    {
        var actionClo: () -> Void = {}
        // TODO: easiest/wrongest way to catch touch events
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)

            actionClo()
        }
    }

    var handler: actionHandler!

    init(named: String, withAction: @escaping () -> Void) {
        super.init(label: named)

        let c = actionHandler(frame: CGRect(x: super.labelWidth, y: 0, width: super.labelWidth, height: height))
        c.setTitle(named, for: .normal)
        c.backgroundColor = UIColor.green

        c.actionClo = withAction

        subviews.forEach({ $0.removeFromSuperview() })// clear

        for d in [c] {
            addSubview(d)

            d.layer.borderColor = UIColor.black.cgColor
            d.layer.borderWidth = 1.0
        }

    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
