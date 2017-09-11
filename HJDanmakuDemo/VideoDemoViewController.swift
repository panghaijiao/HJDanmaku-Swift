//
//  VideoDemoViewController.swift
//  HJDanmaku-Swift
//
//  Created by haijiao on 2017/8/2.
//  Copyright © 2017年 olinone. All rights reserved.
//

import UIKit
import HJDanmaku_Swift

class VideoDemoViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var progressSlider: UISlider!
    @IBOutlet var bufferBtn: UIButton!
    
    var danmakuView: HJDanmakuView!
    var timer: Timer?

    deinit {
        self.danmakuView.stop()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.timer?.invalidate()
        self.timer = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        
        let config = HJDanmakuConfiguration.init(danmakuMode: .HJDanmakuModeVideo)
        self.danmakuView = HJDanmakuView.init(frame: self.view.bounds, configuration: config)
        self.danmakuView.delegate = self
        self.danmakuView.dataSource = self
        self.danmakuView.register(DemoDanmakuCell.self, forCellReuseIdentifier: "cell")
        self.danmakuView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        self.view.insertSubview(self.danmakuView, aboveSubview: self.imageView)
        
        let danmakufile = (Bundle.main.path(forResource: "danmakufile", ofType: nil))!
        let danmakus = NSArray.init(contentsOfFile: danmakufile)!
        let danmakuModels = danmakus.map { (danmaku) -> DemoDanmakuModel in
            let danmaku = danmaku as! NSDictionary
            let pArray = (danmaku["p"] as! NSString).components(separatedBy: ",")
            let typeString: NSString = pArray[1] as NSString;
            let type = HJDanmakuType.init(rawValue: "\(typeString.integerValue % 3)")!
            let danmakuModel = DemoDanmakuModel.init(danmakuType: type)
            danmakuModel.time = CGFloat(Float(pArray[0])! / 1000.0)
            danmakuModel.text = danmaku["m"] as! String
            danmakuModel.textFont = Int(pArray[2]) == 1 ? UIFont.systemFont(ofSize: 20): UIFont.systemFont(ofSize: 18)
            danmakuModel.textColor = UIColor.colorWithHexString(hex: pArray[3] as NSString)
            return danmakuModel
        } as Array<DemoDanmakuModel>!
        self.danmakuView.prepareDanmakus(danmakuModels)
    }
    
    override func systemLayoutFittingSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.systemLayoutFittingSizeDidChange(forChildContentContainer: container)
        self.danmakuView.sizeToFit()
    }
    
    // MARK: - Render
    
    @IBAction func onPlayBtnClick(button: UIButton) {
        if self.danmakuView.isPrepared {
            if self.timer == nil {
                self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(onTimeCount), userInfo: nil, repeats: true)
            }
            self.danmakuView.play()
        }
    }
    
    func onTimeCount() {
        self.progressSlider.value += 0.1 / 120
        if self.progressSlider.value > 120 {
            self.progressSlider.value = 0
        }
        self.timeLabel.text = String.init(format: "%.0fs", self.progressSlider.value * 120.0)
    }
    
    @IBAction func onPauseBtnClick(sender: UIButton) {
        self.danmakuView.pause()
    }
    
    @IBAction func onSendClick(sender: UIButton) {
        let type = HJDanmakuType.init(rawValue: "\(Int(arc4random()) % 3)")!
        let danmakuModel = DemoDanmakuModel.init(danmakuType: type)
        danmakuModel.selfFlag = true
        danmakuModel.time = self.playTimeWithDanmakuView(self.danmakuView) + 0.5
        danmakuModel.text = String.init(format: "%.1f  😊😊olinone.com😊😊", danmakuModel.time)
        danmakuModel.textFont = UIFont.systemFont(ofSize: 20)
        danmakuModel.textColor = UIColor.blue
        self.danmakuView.sendDanmaku(danmakuModel, forceRender: true)
    }
    
    @IBAction func onBufferBtnClick(sender: UIButton) {
        sender.isSelected = !sender.isSelected
    }

}

extension VideoDemoViewController: HJDanmakuViewDelegate {
    
    func prepareCompletedWithDanmakuView(_ danmakuView: HJDanmakuView) {
        self.danmakuView.play()
    }
    
}

extension VideoDemoViewController: HJDanmakuViewDateSource {
    
    func bufferingWithDanmakuView(_ danmakuView: HJDanmakuView) -> Bool {
        return self.bufferBtn.isSelected
    }
    
    func playTimeWithDanmakuView(_ danmakuView: HJDanmakuView) -> CGFloat {
        return CGFloat(self.progressSlider.value * 120)
    }
    
    func danmakuView(_ danmakuView: HJDanmakuView, widthForDanmaku danmaku: HJDanmakuModel) -> CGFloat {
        let model: DemoDanmakuModel = danmaku as! DemoDanmakuModel
        let attributes: [String : Any]? = [NSFontAttributeName: model.textFont]
        return model.text.size(attributes: attributes).width + 1.0
    }
    
    func danmakuView(_ danmakuView: HJDanmakuView, cellForDanmaku danmaku: HJDanmakuModel) -> HJDanmakuCell {
        let model: DemoDanmakuModel = danmaku as! DemoDanmakuModel
        let cell = (danmakuView.dequeueReusableCell(withIdentifier: "cell"))!
        if model.selfFlag {
            cell.zIndex = 30
            cell.layer.borderWidth = 0.5
            cell.layer.borderColor = UIColor.red.cgColor
        }
        cell.textLabel.font = model.textFont
        cell.textLabel.textColor = model.textColor
        cell.textLabel.text = model.text
        return cell
    }
    
}
