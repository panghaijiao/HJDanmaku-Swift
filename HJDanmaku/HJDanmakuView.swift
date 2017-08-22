//
//  HJDanmakuView.swift
//  Pods
//
//  Created by haijiao on 2017/8/2.
//
//

import UIKit

public struct HJDanmakuTime {
    public var time: Float
    public var interval: Float
    public func MaxTime() -> Float {
        return time + interval;
    }
}

open class HJDanmakuView: UIView {

    func dequeueReusableCellWithIdentifier(identifier: String) -> HJDanmakuCell {
        
        let cell: HJDanmakuCell = HJDanmakuCell.init(reuseIdentifier: "cell")
        cell.prepareForReuse()
        
        return HJDanmakuCell.init(reuseIdentifier:"cell")
    }

}
