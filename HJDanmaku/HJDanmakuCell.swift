//
//  HJDanmakuCell.swift
//  Pods
//
//  Created by haijiao on 2017/8/2.
//
//

import UIKit
import Foundation

public enum HJDanmakuCellSelectionStyle {
    case HJDanmakuCellSelectionStyleNone // no select.
    case HJDanmakuCellSelectionStyleDefault
}

open class HJDanmakuCell: UIView {
    
    public var zIndex = 0 // default LR 0  FT/FB 10.
    
    public var selectionStyle: HJDanmakuCellSelectionStyle = .HJDanmakuCellSelectionStyleNone
    
    lazy var textLabel: UILabel = {
        let textLabel = UILabel.init(frame: self.bounds)
        textLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(textLabel)
        return textLabel
    }()
    
    let reuseIdentifier: String
    
    public init(reuseIdentifier: String) {
        self.reuseIdentifier = reuseIdentifier
        super.init(frame: CGRect.zero)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func prepareForReuse() {
        
    }
}
