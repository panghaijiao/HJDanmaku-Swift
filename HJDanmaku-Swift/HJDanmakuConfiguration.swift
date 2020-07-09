//
//  HJDanmakuConfiguration.swift
//  Pods
//
//  Created by haijiao on 2017/8/2.
//
//

import UIKit

public enum HJDanmakuMode {
    case HJDanmakuModeVideo
    case HJDanmakuModeLive
}

open class HJDanmakuConfiguration {
    
    // unit second, greater than zero, default 5.0s
    public var duration: CGFloat = 5.0
    
    // setting a tolerance for a danmaku render later than the time, unit second, default 2.0s
    public var tolerance: CGFloat = 2.0
    
    // default 0, full screen
    public var numberOfLines = 0
    
    // height of single line cell, avoid modify after initialization, default 30.0f
    public var cellHeight: CGFloat = 30.0
    
    // the maximum number of danmakus at the same time, default 0, adapt to the height of screen
    public var maxShowCount = 0
    
    let danmakuMode: HJDanmakuMode
    
    public init(danmakuMode: HJDanmakuMode) {
        self.danmakuMode = danmakuMode
    }
    
}
