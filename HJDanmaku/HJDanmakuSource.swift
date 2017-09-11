//
//  HJDanmakuSource.swift
//  Pods
//
//  Created by haijiao on 2017/9/11.
//
//

import Foundation

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

public class HJDanmakuSource {
    
    var spinLock: OSSpinLock = OS_SPINLOCK_INIT
    var danmakuAgents: Array<HJDanmakuAgent> = Array<HJDanmakuAgent>.init()
    
    static func danmakuSource(withModel mode: HJDanmakuMode) -> HJDanmakuSource {
        return mode == .HJDanmakuModeLive ? HJDanmakuLiveSource.init(): HJDanmakuVideoSource.init()
    }
    
    public func prepareDanmakus(_ danmakus: Array<HJDanmakuModel>, completion: @escaping () -> Swift.Void) {
        assert(false, "subClass implementation")
    }
    
    public func sendDanmaku(_ danmaku: HJDanmakuModel, forceRender force: Bool) {
        assert(false, "subClass implementation")
    }
    
    public func sendDanmakus(_ danmakus: Array<HJDanmakuModel>) {
        assert(false, "subClass implementation")
    }
    
    public func fetchDanmakuAgents(forTime time: HJDanmakuTime) -> Array<HJDanmakuAgent>? {
        assert(false, "subClass implementation");
        return nil
    }
}

public class HJDanmakuVideoSource: HJDanmakuSource {
    
    var lastIndex: Int = 0
    
    override public func prepareDanmakus(_ danmakus: Array<HJDanmakuModel>, completion: @escaping () -> Swift.Void) {
        onGlobalThreadAsync {
            var danmakuAgents = Array<HJDanmakuAgent>.init()
            for danmaku in danmakus {
                let agent = HJDanmakuAgent.init(danmakuModel: danmaku)
                danmakuAgents.append(agent)
            }
            danmakuAgents.sort(by: { (danmakuAgent0, danmakuAgent1) -> Bool in
                return danmakuAgent0.danmakuModel.time > danmakuAgent1.danmakuModel.time
            })
            OSSpinLockLock(&self.spinLock)
            self.danmakuAgents = danmakuAgents
            self.lastIndex = 0
            OSSpinLockUnlock(&self.spinLock)
            completion()
        }
    }
    
    override public func sendDanmaku(_ danmaku: HJDanmakuModel, forceRender force: Bool) {
        let danmakuAgent = HJDanmakuAgent.init(danmakuModel: danmaku)
        danmakuAgent.force = true
        OSSpinLockLock(&self.spinLock)
        let index = self.indexOfDanmakuAgent(danmakuAgent)
        self.danmakuAgents.insert(danmakuAgent, at: index)
        self.lastIndex = 0
        OSSpinLockUnlock(&self.spinLock)
    }
    
    func indexOfDanmakuAgent(_ danmakuAgent: HJDanmakuAgent) -> Int {
        let count = self.danmakuAgents.count
        guard count > 0 else {
            return 0
        }
        let index = self.danmakuAgents.index { (tempDanmakuAgent) -> Bool in
            return danmakuAgent.danmakuModel.time >= tempDanmakuAgent.danmakuModel.time
        }
        return index == nil ? count: index!
    }
    
    override public func sendDanmakus(_ danmakus: Array<HJDanmakuModel>) {
        onGlobalThreadAsync {
            OSSpinLockLock(&self.spinLock)
            var danmakuAgents = Array<HJDanmakuAgent>.init(self.danmakuAgents)
            OSSpinLockUnlock(&self.spinLock)
            for danmaku in danmakus {
                let danmakuAgent = HJDanmakuAgent.init(danmakuModel: danmaku)
                danmakuAgents.append(danmakuAgent)
            }
            danmakuAgents.sort(by: { (danmakuAgent0, danmakuAgent1) -> Bool in
                return danmakuAgent0.danmakuModel.time > danmakuAgent1.danmakuModel.time
            })
            OSSpinLockLock(&self.spinLock)
            self.danmakuAgents = danmakuAgents
            self.lastIndex = 0
            OSSpinLockUnlock(&self.spinLock)
        }
    }
    
    override public func fetchDanmakuAgents(forTime time: HJDanmakuTime) -> Array<HJDanmakuAgent>? {
        OSSpinLockLock(&self.spinLock)
        var lastIndex = self.lastIndex < self.danmakuAgents.count ? self.lastIndex: NSNotFound
        if lastIndex == NSNotFound {
            OSSpinLockUnlock(&self.spinLock)
            return nil
        }
        let lastDanmakuAgent = self.danmakuAgents[self.lastIndex]
        if time.time < lastDanmakuAgent.danmakuModel.time {
            lastIndex = 0
        }
        let minTime = CGFloat(floorf(Float(time.time * 10)) / 10.0)
        let maxTime = time.MaxTime()
        let indexSet = (self.danmakuAgents as NSArray).indexesOfObjects(options: .concurrent) { (agent, idx, stop) -> Bool in
            let danmakuAgent: HJDanmakuAgent = agent as! HJDanmakuAgent
            if danmakuAgent.danmakuModel.time > maxTime {
                stop.pointee = true
            }
            return danmakuAgent.remainingTime <= 0 && danmakuAgent.danmakuModel.time >= minTime && danmakuAgent.danmakuModel.time < maxTime
        }
        if indexSet.count == 0 {
            OSSpinLockUnlock(&self.spinLock)
            return nil
        }
        let danmakuAgents = Array.init(self.danmakuAgents[indexSet.first!...indexSet.last!])
        self.lastIndex = indexSet.first!
        OSSpinLockUnlock(&self.spinLock)
        return danmakuAgents
    }
    
}

public class HJDanmakuLiveSource: HJDanmakuSource {
    
    override public func prepareDanmakus(_ danmakus: Array<HJDanmakuModel>, completion: @escaping () -> Swift.Void) {
        onGlobalThreadAsync {
            var danmakuAgents = Array<HJDanmakuAgent>.init()
            for danmaku in danmakus {
                let agent = HJDanmakuAgent.init(danmakuModel: danmaku)
                danmakuAgents.append(agent)
                OSSpinLockLock(&self.spinLock)
                self.danmakuAgents = danmakuAgents
                OSSpinLockUnlock(&self.spinLock)
                completion()
            }
        }
    }
    
    override public func sendDanmaku(_ danmaku: HJDanmakuModel, forceRender force: Bool) {
        let danmakuAgent = HJDanmakuAgent.init(danmakuModel: danmaku)
        danmakuAgent.force = force
        OSSpinLockLock(&self.spinLock)
        self.danmakuAgents.append(danmakuAgent)
        OSSpinLockUnlock(&self.spinLock)
    }
    
    override public func sendDanmakus(_ danmakus: Array<HJDanmakuModel>) {
        onGlobalThreadAsync {
            let interval = 100
            var danmakuAgents = Array<HJDanmakuAgent>.init()
            let lastIndex = danmakus.count - 1
            for (idx, danmaku) in danmakus.enumerated() {
                let agent = HJDanmakuAgent.init(danmakuModel: danmaku)
                danmakuAgents.append(agent)
                if idx == lastIndex || danmakuAgents.count % interval == 0 {
                    OSSpinLockLock(&self.spinLock)
                    self.danmakuAgents.append(contentsOf: danmakuAgents)
                    OSSpinLockUnlock(&self.spinLock)
                    danmakuAgents.removeAll()
                }
            }
        }
    }
    
    override public func fetchDanmakuAgents(forTime time: HJDanmakuTime) -> Array<HJDanmakuAgent>? {
        OSSpinLockLock(&self.spinLock)
        let danmakuAgents = NSArray.init(array: self.danmakuAgents) as! Array<HJDanmakuAgent>
        self.danmakuAgents.removeAll()
        OSSpinLockUnlock(&self.spinLock)
        return danmakuAgents
    }
    
}
