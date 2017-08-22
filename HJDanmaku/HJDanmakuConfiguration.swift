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
    
    public var danmakuMode: HJDanmakuMode = .HJDanmakuModeVideo
    
    public init(danmakuMode: HJDanmakuMode) {
        self.danmakuMode = danmakuMode
    }
    
}
