//
//  HJDanmakuView.swift
//  Pods
//
//  Created by haijiao on 2017/8/2.
//
//

import UIKit

open class HJDanmakuView: UIView {

    func dequeueReusableCellWithIdentifier(identifier: String) -> HJDanmakuCell {
        
        let cell: HJDanmakuCell = HJDanmakuCell.init(reuseIdentifier: "cell")
        cell.prepareForReuse()
        
        
        return HJDanmakuCell.init(reuseIdentifier:"cell")
    }

}
