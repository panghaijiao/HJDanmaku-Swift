//
//  HJDanmakuModel.swift
//  Pods
//
//  Created by haijiao on 2017/8/2.
//
//

import UIKit

public enum HJDanmakuType: String {
    case HJDanmakuTypeLR = "0"
    case HJDanmakuTypeFT = "1"
    case HJDanmakuTypeFB = "2"
}

open class HJDanmakuModel {
    
    public var time: Float = 0.0  // unit second, ignore when liveModel
    
    let danmakuType: HJDanmakuType
    
    public init(danmakuType: HJDanmakuType) {
        self.danmakuType = danmakuType
    }
    
}
