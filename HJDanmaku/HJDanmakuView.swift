//
//  HJDanmakuView.swift
//  Pods
//
//  Created by haijiao on 2017/8/2.
//
//

import UIKit

func onMainThreadAsync(closure: @escaping () -> ()) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async(execute: closure)
    }
}

func onGlobalThreadAsync(closure: @escaping () -> ()) {
    DispatchQueue.global().async {
        closure()
    }
}

public struct HJDanmakuTime {
    
    public var time: CGFloat
    public var interval: CGFloat
    
    public func MaxTime() -> CGFloat {
        return time + interval;
    }
    
}

public class HJDanmakuAgent {
    
    let danmakuModel: HJDanmakuModel
    var danmakuCell: HJDanmakuCell?
    
    var force: Bool = false
    
    var toleranceCount = 4
    var remainingTime: CGFloat = 5.0
    
    var px: CGFloat = 0
    var py: CGFloat = 0
    var size: CGSize = CGSize.zero
    
    var yIdx: Int = -1 // the line of trajectory, default -1
    
    public init(danmakuModel: HJDanmakuModel) {
        self.danmakuModel = danmakuModel
    }
    
}

//_______________________________________________________________________________________________________________

public protocol HJDanmakuViewDelegate : NSObjectProtocol {
    
    // preparate completed. you can start render after callback
    func prepareCompletedWithDanmakuView(_ danmakuView: HJDanmakuView)
    
    // called before render. return NO will ignore danmaku
    func danmakuView(_ danmakuView: HJDanmakuView, shouldRenderDanmaku danmaku: HJDanmakuModel) -> Bool
    
    // display customization
    func danmakuView(_ danmakuView: HJDanmakuView, willDisplayCell cell: HJDanmakuCell, danmaku: HJDanmakuModel)
    func danmakuView(_ danmakuView: HJDanmakuView, didEndDisplayCell cell: HJDanmakuCell, danmaku: HJDanmakuModel)
    
    // selection customization
    func danmakuView(_ danmakuView: HJDanmakuView, shouldSelectCell cell: HJDanmakuCell, danmaku: HJDanmakuModel) -> Bool
    func danmakuView(_ danmakuView: HJDanmakuView, didSelectCell cell: HJDanmakuCell, danmaku: HJDanmakuModel)
    
}

extension HJDanmakuViewDelegate {
    
    public func prepareCompleted(_ danmakuView: HJDanmakuView) {}
    public func danmakuView(_ danmakuView: HJDanmakuView, shouldRenderDanmaku danmaku: HJDanmakuModel) -> Bool {return true}
    
    public func danmakuView(_ danmakuView: HJDanmakuView, willDisplayCell cell: HJDanmakuCell, danmaku: HJDanmakuModel) {}
    public func danmakuView(_ danmakuView: HJDanmakuView, didEndDisplayCell cell: HJDanmakuCell, danmaku: HJDanmakuModel) {}
    
    public func danmakuView(_ danmakuView: HJDanmakuView, shouldSelectCell cell: HJDanmakuCell, danmaku: HJDanmakuModel) -> Bool {return false}
    public func danmakuView(_ danmakuView: HJDanmakuView, didSelectCell cell: HJDanmakuCell, danmaku: HJDanmakuModel) {}

}

//_______________________________________________________________________________________________________________

public protocol HJDanmakuViewDateSource : NSObjectProtocol {
    
    // variable cell width support
    func danmakuView(_ danmakuView: HJDanmakuView, widthForDanmaku danmaku: HJDanmakuModel) -> CGFloat
    
    // cell display. implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
    func danmakuView(_ danmakuView: HJDanmakuView, cellForDanmaku danmaku: HJDanmakuModel) -> HJDanmakuCell
    
    // current play time, unit second, must implementation when videoModel
    func playTimeWithDanmakuView(_ danmakuView: HJDanmakuView) -> CGFloat
    
    // play buffer status, when YES, stop render new danmaku, rendered danmaku in screen will continue anim until disappears, only valid when videoModel
    func bufferingWithDanmakuView(_ danmakuView: HJDanmakuView) -> Bool
    
}

extension HJDanmakuViewDateSource {
    
    public func playTimeWithDanmakuView(_ danmakuView: HJDanmakuView) -> CGFloat {return 0}
    
    public func bufferingWithDanmakuView(_ danmakuView: HJDanmakuView) -> Bool {return false}
    
}

//_______________________________________________________________________________________________________________

fileprivate let HJFrameInterval: CGFloat = 0.2

open class HJDanmakuView: UIView {
    
    weak open var dataSource: HJDanmakuViewDateSource?
    weak open var delegate: HJDanmakuViewDelegate?
    
    public private(set) var isPrepared = false
    public private(set) var isPlaying = false
    
    public let configuration: HJDanmakuConfiguration
    
    var reuseLock: OSSpinLock = OS_SPINLOCK_INIT
    lazy var renderQueue: DispatchQueue = {
        return DispatchQueue.init(label: "com.olinone.danmaku.renderQueue")
    }()
    
    var toleranceCount: Int
    var renderBounds = CGRect.zero
    
    var danmakuSource: HJDanmakuSource
    lazy var sourceQueue: OperationQueue = {
        var newSourceQueue = OperationQueue.init()
        newSourceQueue.name = "com.olinone.danmaku.sourceQueue"
        newSourceQueue.maxConcurrentOperationCount = 1
        return newSourceQueue
    }()
    
    var displayLink: CADisplayLink?
    var playTime: HJDanmakuTime = HJDanmakuTime.init(time: 0, interval: HJFrameInterval)
    
    var cellClassInfo: Dictionary = Dictionary<String, HJDanmakuCell.Type>.init()
    var cellReusePool: Dictionary = Dictionary<String, Array<HJDanmakuCell>>.init()
    
    var danmakuQueuePool: Array = Array<HJDanmakuAgent>.init()
    var renderingDanmakus: Array = Array<HJDanmakuAgent>.init()
    
    var LRRetainer: Dictionary = Dictionary<NSNumber, HJDanmakuAgent>.init()
    var FTRetainer: Dictionary = Dictionary<NSNumber, HJDanmakuAgent>.init()
    var FBRetainer: Dictionary = Dictionary<NSNumber, HJDanmakuAgent>.init()
    
    var selectDanmakuAgent: HJDanmakuAgent?
    
    public init(frame: CGRect, configuration: HJDanmakuConfiguration) {
        self.configuration = configuration
        self.toleranceCount = Int(self.configuration.tolerance / HJFrameInterval)
        self.toleranceCount = max(self.toleranceCount, 1)
        self.danmakuSource = HJDanmakuSource.danmakuSource(withModel: configuration.danmakuMode)
        
        super.init(frame: frame)
        self.clipsToBounds = true
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // you can prepare with nil when liveModel
    public func prepareDanmakus(_ danmakus: Array<HJDanmakuModel>?) {
        self.isPrepared = false
        self.stop()
        
        guard let danmakus = danmakus else {
            self.isPrepared = true
            onMainThreadAsync {
                self.delegate?.prepareCompletedWithDanmakuView(self)
            }
            return
        }
        
        self.danmakuSource.prepareDanmakus(danmakus, completion: {
            self.preloadDanmakusWhenPrepare()
            self.isPrepared = true
            onMainThreadAsync {
                self.delegate?.prepareCompletedWithDanmakuView(self)
            }
        })
    }

    // be sure to call -prepareDanmakus before -play, when isPrepared is NO, call will be invalid
    public func play() {
        guard self.configuration.duration > 0 else {
            assert(false, "configuration nil or duration <= 0")
            return
        }
        guard self.isPrepared else {
            assert(false, "isPrepared is NO!")
            return
        }
        
        if self.isPlaying {
            return
        }
        self.isPlaying = true
        self.resumeDisplayingDanmakus()
        if self.displayLink == nil {
            self.displayLink = CADisplayLink.init(target: self, selector: #selector(update))
            self.displayLink!.frameInterval = Int(60.0 * HJFrameInterval)
            self.displayLink!.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
        }
        self.displayLink?.isPaused = false;
    }
    
    public func pause() {
        if !self.isPlaying {
            return
        }
        self.isPlaying = false
        self.displayLink?.isPaused = true
        self.pauseDisplayingDanmakus()
    }
    
    public func stop() {
        self.isPlaying = false
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.playTime = HJDanmakuTime.init(time: 0, interval: HJFrameInterval)
        renderQueue.async {
            self.danmakuQueuePool.removeAll()
        }
        self.clearScreen()
    }
    
    public func clearScreen() {
        self.recycleDanmakuAgents(self.renderingDanmakus)
        self.renderQueue.async {
            self.renderingDanmakus.removeAll()
            self.LRRetainer.removeAll()
            self.FTRetainer.removeAll()
            self.FBRetainer.removeAll()
        }
    }
    
    override open func sizeToFit() {
        super.sizeToFit()
        let danmakuAgents = self.visibleDanmakuAgents()
        onMainThreadAsync {
            let midX = self.bounds.midX
            let height = self.bounds.height
            for danmakuAgent in danmakuAgents {
                if danmakuAgent.danmakuModel.danmakuType != .HJDanmakuTypeLR {
                    var centerPoint = danmakuAgent.danmakuCell!.center
                    centerPoint.x = midX
                    danmakuAgent.danmakuCell!.center = centerPoint
                    if danmakuAgent.danmakuModel.danmakuType == .HJDanmakuTypeFB {
                        var rect: CGRect = danmakuAgent.danmakuCell!.frame
                        rect.origin.y = height - self.configuration.cellHeight * CGFloat(danmakuAgent.yIdx + 1)
                        danmakuAgent.danmakuCell!.frame = rect
                    }
                }
            }
        }
    }
    
    /* send customization. when force, renderer will draw the danmaku immediately and ignore the maximum quantity limit.
     you should call -sendDanmakus: instead of -sendDanmaku:forceRender: to send the danmakus from a remote servers
     */
    public func sendDanmaku(_ danmaku: HJDanmakuModel, forceRender force: Bool) {
        self.danmakuSource.sendDanmaku(danmaku, forceRender: force)
        
        if force {
            var time = HJDanmakuTime.init(time: 0, interval: HJFrameInterval)
            time.time = (self.dataSource?.playTimeWithDanmakuView(self))!
            self.loadDanmakusFromSource(forTime: time)
        }
    }
    
    public func sendDanmakus(_ danmakus: Array<HJDanmakuModel>) {
        self.danmakuSource.sendDanmakus(danmakus)
    }
    
    // returns nil if cell is not visible
    public func danmakuForVisibleCell(_ danmakuCell: HJDanmakuCell) -> HJDanmakuModel? {
        let danmakuAgents = self.visibleDanmakuAgents()
        for danmakuAgent in danmakuAgents {
            if danmakuAgent.danmakuCell == danmakuCell {
                return danmakuAgent.danmakuModel
            }
        }
        return nil
    }
    
    public var visibleCells: Array<HJDanmakuCell> {
        get {
            var visibleCells = Array<HJDanmakuCell>()
            renderQueue.sync {
                for danmakuAgent in self.renderingDanmakus {
                    let danmakuCell = danmakuAgent.danmakuCell
                    if let cell = danmakuCell {
                        visibleCells.append(cell)
                    }
                }
            }
            return visibleCells;
        }
    }
    
    func visibleDanmakuAgents() -> Array<HJDanmakuAgent> {
        var renderingDanmakus: Array<HJDanmakuAgent>!
        renderQueue.sync {
            renderingDanmakus = Array.init(self.renderingDanmakus)
        }
        return renderingDanmakus;
    }
}

extension HJDanmakuView {
    
    func preloadDanmakusWhenPrepare() {
        let operation = BlockOperation.init { 
            let danmakuAgents: Array<HJDanmakuAgent> = self.danmakuSource.fetchDanmakuAgents(forTime: self.playTime)!
            for danmakuAgent in danmakuAgents {
                danmakuAgent.remainingTime = self.configuration.duration
                danmakuAgent.toleranceCount = self.toleranceCount
            }
            self.renderQueue.async {
                self.danmakuQueuePool.append(contentsOf: danmakuAgents)
            }
        }
        self.sourceQueue.cancelAllOperations()
        self.sourceQueue.addOperation(operation)
    }
    
    func pauseDisplayingDanmakus() {
        let danmakuAgents = self.visibleDanmakuAgents()
        onMainThreadAsync {
            for danmakuAgent in danmakuAgents {
                if danmakuAgent.danmakuModel.danmakuType == .HJDanmakuTypeLR {
                    let layer: CALayer = danmakuAgent.danmakuCell!.layer
                    danmakuAgent.danmakuCell!.frame = layer.presentation()!.frame
                    danmakuAgent.danmakuCell!.layer.removeAllAnimations()
                }
            }
        }
    }
    
    func resumeDisplayingDanmakus() {
        let danmakuAgents = self.visibleDanmakuAgents()
        onMainThreadAsync {
            for danmakuAgent in danmakuAgents {
                if danmakuAgent.danmakuModel.danmakuType == .HJDanmakuTypeLR {
                    UIView.animate(withDuration: TimeInterval(danmakuAgent.remainingTime), delay: 0, options: UIViewAnimationOptions.curveLinear, animations: {
                        danmakuAgent.danmakuCell!.frame = CGRect.init(origin: CGPoint.init(x: -danmakuAgent.size.width, y: danmakuAgent.py), size: danmakuAgent.size)
                    }, completion: nil)
                }
            }
        }
    }
    
    // MARK: - Render
    
    func update() {
        var time = HJDanmakuTime.init(time: 0, interval: HJFrameInterval)
        time.time = (self.dataSource?.playTimeWithDanmakuView(self))!
        if self.configuration.danmakuMode == .HJDanmakuModeVideo && time.time <= 0 {
            return;
        }
        let isBuffering = (self.dataSource?.bufferingWithDanmakuView(self))!
        if !isBuffering {
            self.loadDanmakusFromSource(forTime: time)
        }
        self.renderDanmakus(forTime: time, buffering: isBuffering)
    }
    
    func loadDanmakusFromSource(forTime time: HJDanmakuTime) {
        let operation = BlockOperation.init { 
            let fetchDanmakuAgents = self.danmakuSource.fetchDanmakuAgents(forTime: HJDanmakuTime.init(time: time.MaxTime(), interval: time.interval))
            guard var danmakuAgents = fetchDanmakuAgents else {
                return;
            }
            danmakuAgents = danmakuAgents.filter({ (danmakuAgent) -> Bool in
                return danmakuAgent.remainingTime > 0
            })
            for danmakuAgent in danmakuAgents {
                danmakuAgent.remainingTime = self.configuration.duration
                danmakuAgent.toleranceCount = self.toleranceCount
            }
            self.renderQueue.async {
                if time.time < self.playTime.time || time.time > self.playTime.MaxTime() + self.configuration.tolerance {
                    self.danmakuQueuePool.removeAll()
                }
                if danmakuAgents.count > 0 {
                    self.danmakuQueuePool.insert(contentsOf: danmakuAgents, at: 0)
                }
                self.playTime = time
            }
        }
        self.sourceQueue.cancelAllOperations()
        self.sourceQueue.addOperation(operation)
    }
    
    func renderDanmakus(forTime time: HJDanmakuTime, buffering isBuffering: Bool) {
        self.renderBounds = self.bounds
        self.renderQueue.async {
            self.renderDisplayingDanmakus(forTime: time)
            if !isBuffering {
                self.renderNewDanmakus(forTime: time)
                self.removeExpiredDanmakus(forTime: time)
            }
        }
    }
    
    func renderDisplayingDanmakus(forTime time: HJDanmakuTime) {
        var disappearDanmakuAgens: Array<HJDanmakuAgent> = Array.init()
        for (idx, danmakuAgent) in self.renderingDanmakus.enumerated().reversed() {
            danmakuAgent.remainingTime -= time.interval
            if danmakuAgent.remainingTime <= 0 {
                disappearDanmakuAgens.append(danmakuAgent)
                self.renderingDanmakus.remove(at: idx)
            }
        }
        self.recycleDanmakuAgents(disappearDanmakuAgens)
    }
    
    func recycleDanmakuAgents(_ danmakuAgents: Array<HJDanmakuAgent>) {
        if danmakuAgents.count == 0 {
            return
        }
        onMainThreadAsync {
            for danmakuAgent in danmakuAgents {
                danmakuAgent.danmakuCell?.layer.removeAllAnimations()
                danmakuAgent.danmakuCell?.removeFromSuperview()
                danmakuAgent.yIdx = -1
                danmakuAgent.remainingTime = 0
                self.recycleCellToReusePool(danmakuAgent.danmakuCell!)
                self.delegate?.danmakuView(self, didEndDisplayCell: danmakuAgent.danmakuCell!, danmaku: danmakuAgent.danmakuModel)
            }
        }
    }
    
    func renderNewDanmakus(forTime time: HJDanmakuTime) {
        let maxShowCount = self.configuration.maxShowCount > 0 ? self.configuration.maxShowCount: Int.max
        var renderResult = Dictionary<String, Bool>.init()
        for danmakuAgent in self.danmakuQueuePool {
            let retainKey = danmakuAgent.danmakuModel.danmakuType.rawValue
            if !danmakuAgent.force {
                if self.renderingDanmakus.count > maxShowCount {
                    break
                }
                if renderResult.keys.contains(HJDanmakuType.HJDanmakuTypeLR.rawValue) &&
                    renderResult.keys.contains(HJDanmakuType.HJDanmakuTypeFT.rawValue) &&
                    renderResult.keys.contains(HJDanmakuType.HJDanmakuTypeFB.rawValue) {
                    break
                }
                if renderResult.keys.contains(retainKey) {
                    continue
                }
            }
            guard (self.delegate?.danmakuView(self, shouldRenderDanmaku: danmakuAgent.danmakuModel))! else {
                continue
            }
            if !self.renderNewDanmaku(danmakuAgent, forTime: time) {
                renderResult[retainKey] = true
            }
        }
    }
    
    func renderNewDanmaku(_ danmakuAgent: HJDanmakuAgent, forTime time: HJDanmakuTime) -> Bool {
        if !self.layoutNewDanmaku(danmakuAgent, forTime: time) {
            return false
        }
        self.renderingDanmakus.append(danmakuAgent)
        danmakuAgent.toleranceCount = 0
        onMainThreadAsync {
            danmakuAgent.danmakuCell = {
                let cell = (self.dataSource?.danmakuView(self, cellForDanmaku: danmakuAgent.danmakuModel))!
                cell.frame = CGRect.init(origin: CGPoint.init(x: danmakuAgent.px, y: danmakuAgent.py), size: danmakuAgent.size)
                cell.zIndex = 0
                return cell
            }()
            self.delegate?.danmakuView(self, willDisplayCell: danmakuAgent.danmakuCell!, danmaku: danmakuAgent.danmakuModel)
            self.insertSubview(danmakuAgent.danmakuCell!, at: danmakuAgent.danmakuCell!.zIndex)
            if danmakuAgent.danmakuModel.danmakuType == .HJDanmakuTypeLR {
                UIView.animate(withDuration: TimeInterval(danmakuAgent.remainingTime), delay: 0, options: UIViewAnimationOptions.curveLinear, animations: {
                    danmakuAgent.danmakuCell!.frame = CGRect.init(origin: CGPoint.init(x: -danmakuAgent.size.width, y: danmakuAgent.py), size: danmakuAgent.size)
                }, completion: nil)
            }
            
        }
        return true
    }
    
    func removeExpiredDanmakus(forTime time: HJDanmakuTime) {
        for (idx, danmakuAgent) in self.danmakuQueuePool.enumerated().reversed() {
            danmakuAgent.toleranceCount -= 1
            if danmakuAgent.toleranceCount <= 0 {
                self.danmakuQueuePool.remove(at: idx)
            }
        }
    }
    
    // MARK: - Retainer
    
    func layoutNewDanmaku(_ danmakuAgent: HJDanmakuAgent, forTime time: HJDanmakuTime) -> Bool {
        let width = (self.dataSource?.danmakuView(self, widthForDanmaku: danmakuAgent.danmakuModel))!
        danmakuAgent.size = CGSize.init(width: width, height: self.configuration.cellHeight)
        let py = self.layoutPyWithNewDanmaku(danmakuAgent, forTime: time)
        guard py >= 0 else {
            return false
        }
        danmakuAgent.py = py
        danmakuAgent.px = danmakuAgent.danmakuModel.danmakuType == .HJDanmakuTypeLR ? self.renderBounds.width: (self.renderBounds.midX - danmakuAgent.size.width / 2)
        return true
    }
    
    func layoutPyWithNewDanmaku(_ danmakuAgent: HJDanmakuAgent, forTime time: HJDanmakuTime) -> CGFloat {
        switch danmakuAgent.danmakuModel.danmakuType {
        case .HJDanmakuTypeLR:
            return self.layoutPyWithLRDanmaku(danmakuAgent, forTime: time)
        case .HJDanmakuTypeFT:
            return self.layoutPyWithFTDanmaku(danmakuAgent, forTime: time)
        case .HJDanmakuTypeFB:
            return self.layoutPyWithFBDanmaku(danmakuAgent, forTime: time)
        }
    }
    
    // LR
    func layoutPyWithLRDanmaku(_ danmakuAgent: HJDanmakuAgent, forTime time: HJDanmakuTime) -> CGFloat {
        let maxPyIndex = self.configuration.numberOfLines > 0 ? self.configuration.numberOfLines: Int(self.renderBounds.height / self.configuration.cellHeight)
        for index in 0..<maxPyIndex {
            let key = NSNumber.init(value: index)
            guard let tempAgent = self.LRRetainer[key] else {
                danmakuAgent.yIdx = index
                self.LRRetainer[key] = danmakuAgent
                return self.configuration.cellHeight * CGFloat(index)
            }
            if !self.checkLRIsWillHitWithPreDanmaku(tempAgent, danmaku: danmakuAgent) {
                danmakuAgent.yIdx = index
                self.LRRetainer[key] = danmakuAgent
                return self.configuration.cellHeight * CGFloat(index)
            }
        }
        if danmakuAgent.force {
            let index = Int(arc4random()) % maxPyIndex
            danmakuAgent.yIdx = index
            let key = NSNumber.init(value: index)
            self.LRRetainer[key] = danmakuAgent
            return self.configuration.cellHeight * CGFloat(index)
        }
        return -1
    }
    
    func checkLRIsWillHitWithPreDanmaku(_ preDanmakuAgent: HJDanmakuAgent, danmaku danmakuAgent: HJDanmakuAgent) -> Bool {
        guard preDanmakuAgent.remainingTime > 0 else {
            return false
        }
        let preDanmakuSpeed = (self.renderBounds.width + preDanmakuAgent.size.width) / self.configuration.duration
        if preDanmakuSpeed * (self.configuration.duration  - preDanmakuAgent.remainingTime) < preDanmakuAgent.size.width {
            return true
        }
        let curDanmakuSpeed = (self.renderBounds.width + danmakuAgent.size.width) / self.configuration.duration
        if curDanmakuSpeed * preDanmakuAgent.remainingTime > self.renderBounds.width {
            return true
        }
        return false
    }
    
    // FT
    func layoutPyWithFTDanmaku(_ danmakuAgent: HJDanmakuAgent, forTime time: HJDanmakuTime) -> CGFloat {
        let maxPyIndex = self.configuration.numberOfLines > 0 ? self.configuration.numberOfLines: Int(self.renderBounds.height / 2.0 / self.configuration.cellHeight)
        for index in 0..<maxPyIndex {
            let key = NSNumber.init(value: index)
            guard let tempAgent = self.FTRetainer[key] else {
                danmakuAgent.yIdx = index
                self.FTRetainer[key] = danmakuAgent
                return self.configuration.cellHeight * CGFloat(index)
            }
            if !self.checkFTIsWillHitWithPreDanmaku(tempAgent, danmaku: danmakuAgent) {
                danmakuAgent.yIdx = index
                self.FTRetainer[key] = danmakuAgent
                return self.configuration.cellHeight * CGFloat(index)
            }
        }
        if danmakuAgent.force {
            let index = Int(arc4random()) % maxPyIndex
            danmakuAgent.yIdx = index
            let key = NSNumber.init(value: index)
            self.FTRetainer[key] = danmakuAgent
            return self.configuration.cellHeight * CGFloat(index)
        }
        return -1
    }
    
    func checkFTIsWillHitWithPreDanmaku(_ preDanmakuAgent: HJDanmakuAgent, danmaku danmakuAgent: HJDanmakuAgent) -> Bool {
        if preDanmakuAgent.remainingTime <= 0 {
            return false
        }
        return true
    }
    
    // FB
    func layoutPyWithFBDanmaku(_ danmakuAgent: HJDanmakuAgent, forTime time: HJDanmakuTime) -> CGFloat {
        let maxPyIndex = self.configuration.numberOfLines > 0 ? self.configuration.numberOfLines: Int(self.renderBounds.height / 2.0 / self.configuration.cellHeight)
        for index in 0..<maxPyIndex {
            let key = NSNumber.init(value: index)
            guard let tempAgent = self.FBRetainer[key] else {
                danmakuAgent.yIdx = index
                self.FBRetainer[key] = danmakuAgent
                return self.renderBounds.height - self.configuration.cellHeight * CGFloat(index + 1)
            }
            if !self.checkFTIsWillHitWithPreDanmaku(tempAgent, danmaku: danmakuAgent) {
                danmakuAgent.yIdx = index
                self.FBRetainer[key] = danmakuAgent
                return self.renderBounds.height - self.configuration.cellHeight * CGFloat(index + 1)
            }
        }
        if danmakuAgent.force {
            let index = Int(arc4random()) % maxPyIndex
            danmakuAgent.yIdx = index
            let key = NSNumber.init(value: index)
            self.FBRetainer[key] = danmakuAgent
            return self.renderBounds.height - self.configuration.cellHeight * CGFloat(index + 1)
        }
        return -1
    }
    
    func checkFBIsWillHitWithPreDanmaku(_ preDanmakuAgent: HJDanmakuAgent, danmaku danmakuAgent: HJDanmakuAgent) -> Bool {
        if preDanmakuAgent.remainingTime <= 0 {
            return false
        }
        return true
    }
    
}

// MARK: - Touch

extension HJDanmakuView {
    
    func danmakuAgentAtPoint(_ point: CGPoint) -> HJDanmakuAgent? {
        var sortDanmakuAgents = self.visibleDanmakuAgents()
        guard sortDanmakuAgents.count > 0 else {
            return nil
        }
        sortDanmakuAgents.sort { (obj1, obj2) -> Bool in
            return obj1.danmakuCell!.zIndex > obj2.danmakuCell!.zIndex
        }
        for danmakuAgent in sortDanmakuAgents {
            let rect = danmakuAgent.danmakuCell!.layer.presentation()!.frame
            if rect.contains(point) {
                return danmakuAgent
            }
        }
        return nil
    }
    
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        self.selectDanmakuAgent = nil
        if let danmakuAgent = self.danmakuAgentAtPoint(point) {
            if danmakuAgent.danmakuCell!.selectionStyle == .HJDanmakuCellSelectionStyleDefault {
                self.selectDanmakuAgent = danmakuAgent
                return self
            }
            let cellPoint = self.convert(point, to: danmakuAgent.danmakuCell!)
            return danmakuAgent.danmakuCell!.hitTest(cellPoint, with: event)
        }
        return super.hitTest(point, with: event)
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let selectDanmakuAgent = self.selectDanmakuAgent else {
            return
        }
        let shouldSelect: Bool = (self.delegate?.danmakuView(self, shouldSelectCell: selectDanmakuAgent.danmakuCell!, danmaku: selectDanmakuAgent.danmakuModel))!
        if !shouldSelect {
            self.selectDanmakuAgent = nil
        }
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let selectDanmakuAgent = self.selectDanmakuAgent else {
            return
        }
        let rect = selectDanmakuAgent.danmakuCell!.layer.presentation()!.frame
        let point = touches.first?.location(in: self)
        guard let touchPoint = point else {
            return
        }
        if !rect.contains(touchPoint) {
            self.selectDanmakuAgent = nil
        }
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let selectDanmakuAgent = self.selectDanmakuAgent else {
            return
        }
        let rect = selectDanmakuAgent.danmakuCell!.layer.presentation()!.frame
        let point = touches.first?.location(in: self)
        guard let touchPoint = point else {
            return
        }
        if rect.contains(touchPoint) {
            self.delegate?.danmakuView(self, didSelectCell: selectDanmakuAgent.danmakuCell!, danmaku: selectDanmakuAgent.danmakuModel)
            self.selectDanmakuAgent = nil
        }
    }
    
    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        self.selectDanmakuAgent = nil
    }
    
}

extension HJDanmakuView {
    
    public func register(_ cellClass: HJDanmakuCell.Type, forCellReuseIdentifier identifier: String) {
        self.cellClassInfo[identifier] = cellClass
    }
    
    public func dequeueReusableCell(withIdentifier identifier: String) -> HJDanmakuCell? {
        let cells = self.cellReusePool[identifier]
        if cells == nil || cells!.count == 0 {
            let cellClass: HJDanmakuCell.Type? = self.cellClassInfo[identifier]
            guard let cellType = cellClass else {
                return nil
            }
            let cell = cellType.init(reuseIdentifier: identifier)
            return cell
        }
        OSSpinLockLock(&reuseLock);
        let cell: HJDanmakuCell = cells!.last!
        OSSpinLockUnlock(&reuseLock);
        cell.zIndex = 0
        cell.prepareForReuse()
        return cell
    }
    
    func recycleCellToReusePool(_ danmakuCell: HJDanmakuCell) {
        let identifier: String = danmakuCell.reuseIdentifier
        OSSpinLockLock(&reuseLock);
        var cells = self.cellReusePool[identifier]
        if cells == nil {
            cells = Array.init()
        }
        cells!.append(danmakuCell)
        OSSpinLockUnlock(&reuseLock);
    }
    
}
