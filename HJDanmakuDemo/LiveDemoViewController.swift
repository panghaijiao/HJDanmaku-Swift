//
//  LiveDemoViewController.swift
//  HJDanmaku-Swift
//
//  Created by haijiao on 2017/8/2.
//  Copyright © 2017年 olinone. All rights reserved.
//

import UIKit
import HJDanmaku_Swift

extension UIColor {
    
    static func colorWithHexString (hex: NSString) -> UIColor {
        var cString: NSString = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased() as NSString
        if (cString.hasPrefix("#")) {
            cString = cString.substring(from: 1) as NSString
        }
        
        if cString.length != 6 {
            return UIColor.gray
        }
    
        let rString = cString.substring(to: 2)
        let gString = cString.substring(with: NSRange.init(location: 2, length: 2))
        let bString = cString.substring(with: NSRange.init(location: 4, length: 2))
        
        var r:CUnsignedInt = 0, g:CUnsignedInt = 0, b:CUnsignedInt = 0;
        Scanner.init(string: rString).scanHexInt32(&r)
        Scanner.init(string: gString).scanHexInt32(&g)
        Scanner.init(string: bString).scanHexInt32(&b)
        return UIColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: CGFloat(1))
    }
    
}


class LiveDemoViewController: UIViewController {
    
    var index = 0
    lazy var danmakus: NSArray = {
        let danmakufile = (Bundle.main.path(forResource: "danmakufile", ofType: nil))!
        return NSArray.init(contentsOfFile: danmakufile)!
    }()
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var panelView: UIView!
    @IBOutlet var alphaSlider: UISlider!
    
    var danmakuView: HJDanmakuView!
    var timer: Timer?
    
    deinit {
        self.danmakuView.stop()
    }
    
    @IBAction func onBackClick(button: UIButton) {
        button.isHidden = true
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.popViewController(animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.timer?.invalidate()
        self.timer = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.white
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        
        let config = HJDanmakuConfiguration.init(danmakuMode: .HJDanmakuModeLive)
        self.danmakuView = HJDanmakuView.init(frame: self.view.bounds, configuration: config)
        self.danmakuView.delegate = self
        self.danmakuView.dataSource = self
        self.danmakuView.register(DemoDanmakuCell.self, forCellReuseIdentifier: "cell")
        self.danmakuView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        self.view.insertSubview(self.danmakuView, aboveSubview: self.imageView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !self.danmakuView.isPrepared {
            self.danmakuView.prepareDanmakus(nil)
        }
    }
    
    override func systemLayoutFittingSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.systemLayoutFittingSizeDidChange(forChildContentContainer: container)
        self.danmakuView.sizeToFit()
    }
    
    // MARK: - Render
    
    @IBAction func onPlayBtnClick(button: UIButton) {
        if self.danmakuView.isPrepared {
            if self.timer == nil {
                self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(randomSendNewDanmaku), userInfo: nil, repeats: true)
            }
            self.danmakuView.play()
        }
    }
    
    func randomSendNewDanmaku() {
        self.index += 1
        if self.index >= self.danmakus.count {
            return
        }
        let danmaku = self.danmakus[self.index] as! NSDictionary
        let pArray = (danmaku["p"] as! NSString).components(separatedBy: ",")
        let typeString: NSString = pArray[1] as NSString;
        let type = HJDanmakuType.init(rawValue: "\(typeString.integerValue % 3)")!
        let danmakuModel = DemoDanmakuModel.init(danmakuType: type)
        danmakuModel.text = danmaku["m"] as! String
        danmakuModel.textFont = Int(pArray[2]) == 1 ? UIFont.systemFont(ofSize: 20): UIFont.systemFont(ofSize: 18)
        danmakuModel.textColor = UIColor.colorWithHexString(hex: pArray[3] as NSString)
        self.danmakuView.sendDanmaku(danmakuModel, forceRender: false)
    }
    
    @IBAction func onPauseBtnClick(sender: UIButton) {
        self.danmakuView.pause()
    }
    
    @IBAction func onSendClick(sender: UIButton) {
        let type = HJDanmakuType.init(rawValue: "\(Int(arc4random()) % 3)")!
        let danmakuModel = DemoDanmakuModel.init(danmakuType: type)
        danmakuModel.selfFlag = true
        danmakuModel.text = "😊😊olinone.com😊😊"
        danmakuModel.textFont = UIFont.systemFont(ofSize: 20)
        danmakuModel.textColor = UIColor.blue
        self.danmakuView.sendDanmaku(danmakuModel, forceRender: true)
    }
    
    @IBAction func onSetBtnClick(sender: UIButton) {
        sender.isSelected = !sender.isSelected
        var rect = self.panelView.frame
        rect.size.height = sender.isSelected ? 83.0 : 45.0
        rect.origin.y = self.view.bounds.height - rect.size.height
        UIView.animate(withDuration: 0.3) { 
            self.panelView.frame = rect
        }
    }
    
    @IBAction func onAlphaChange(sender: UISlider) {
        let cells = self.danmakuView.visibleCells
        for cell in cells {
            cell.alpha = CGFloat(sender.value)
        }
    }
    
    @IBAction func onCountChange(sender: UISlider) {
        self.danmakuView.configuration.maxShowCount = Int(sender.value * 30)
    }
    
}

extension LiveDemoViewController: HJDanmakuViewDelegate {
    
    func prepareCompletedWithDanmakuView(_ danmakuView: HJDanmakuView) {
        self.danmakuView.play()
    }
    
    func danmakuView(_ danmakuView: HJDanmakuView, shouldSelectCell cell: HJDanmakuCell, danmaku: HJDanmakuModel) -> Bool {
        return danmaku.danmakuType == .HJDanmakuTypeLR ? true: false
    }
    
    func danmakuView(_ danmakuView: HJDanmakuView, didSelectCell cell: HJDanmakuCell, danmaku: HJDanmakuModel) {
        print("select=> \(cell.textLabel.text!)")
    }
    
}

extension LiveDemoViewController: HJDanmakuViewDateSource {
    
    func danmakuView(_ danmakuView: HJDanmakuView, widthForDanmaku danmaku: HJDanmakuModel) -> CGFloat {
        let model: DemoDanmakuModel = danmaku as! DemoDanmakuModel
        let attributes: [String : Any]? = [NSFontAttributeName: model.textFont]
        return model.text.size(attributes: attributes).width + 1.0
    }

    func danmakuView(_ danmakuView: HJDanmakuView, cellForDanmaku danmaku: HJDanmakuModel) -> HJDanmakuCell {
        let model: DemoDanmakuModel = danmaku as! DemoDanmakuModel
        let cell = (danmakuView.dequeueReusableCell(withIdentifier: "cell"))!
        cell.alpha = CGFloat(self.alphaSlider.value)
        if model.selfFlag {
            cell.zIndex = 30
            cell.layer.borderWidth = 0.5
            cell.layer.borderColor = UIColor.red.cgColor
        }
        cell.selectionStyle = .HJDanmakuCellSelectionStyleDefault
        cell.textLabel.font = model.textFont
        cell.textLabel.textColor = model.textColor
        cell.textLabel.text = model.text
        return cell
    }
    
}
