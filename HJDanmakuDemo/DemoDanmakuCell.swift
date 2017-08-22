//
//  DemoDanmakuCell.swift
//  HJDanmaku-Swift
//
//  Created by haijiao on 2017/8/15.
//  Copyright © 2017年 olinone. All rights reserved.
//

import UIKit
import HJDanmaku_Swift

class DemoDanmakuCell: HJDanmakuCell {
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.layer.borderWidth = 0
    }

}
