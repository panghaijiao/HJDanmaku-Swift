//
//  HJDanmakuSource.swift
//  Pods
//
//  Created by haijiao on 2017/9/11.
//
//

import Foundation
import UIKit

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
    var remainingTime: CGFloat = 0
    
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
    
    let semaphore = DispatchSemaphore(value: 1)
    
    var danmakuAgents: Array<HJDanmakuAgent> = Array<HJDanmakuAgent>.init()
    
    static func danmakuSource(withModel mode: HJDanmakuMode) -> HJDanmakuSource {
        return mode == .HJDanmakuModeLive ? HJDanmakuLiveSource.init(): HJDanmakuVideoSource.init()
    }
    
    public func prepareDanmakus(_ danmakus: Array<HJDanmakuModel>, completion: @escaping () -> Swift.Void) {
        assert(false, "subClass implementation")
    }
    
    @discardableResult
    public func sendDanmaku(_ danmaku: HJDanmakuModel, forceRender force: Bool) -> HJDanmakuAgent? {
        assert(false, "subClass implementation")
        return nil
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
                return danmakuAgent0.danmakuModel.time < danmakuAgent1.danmakuModel.time
            })
            self.semaphore.wait()
            self.danmakuAgents = danmakuAgents
            self.lastIndex = 0
            self.semaphore.signal()
            completion()
        }
    }
    
    override public func sendDanmaku(_ danmaku: HJDanmakuModel, forceRender force: Bool) -> HJDanmakuAgent? {
        let danmakuAgent = HJDanmakuAgent.init(danmakuModel: danmaku)
        danmakuAgent.force = true
        self.semaphore.wait()
        let index = self.indexOfDanmakuAgent(danmakuAgent)
        self.danmakuAgents.insert(danmakuAgent, at: index)
        self.lastIndex = 0
        self.semaphore.signal()
        
        return danmakuAgent
    }
    
    func indexOfDanmakuAgent(_ danmakuAgent: HJDanmakuAgent) -> Int {
        let count = self.danmakuAgents.count
        guard count > 0 else {
            return 0
        }
        let index = self.danmakuAgents.firstIndex { (tempDanmakuAgent) -> Bool in
            return danmakuAgent.danmakuModel.time <= tempDanmakuAgent.danmakuModel.time
        }
        return index == nil ? count: index!
    }
    
    override public func sendDanmakus(_ danmakus: Array<HJDanmakuModel>) {
        onGlobalThreadAsync {
            self.semaphore.wait()
            var danmakuAgents = Array<HJDanmakuAgent>.init(self.danmakuAgents)
            self.semaphore.signal()
            for danmaku in danmakus {
                let danmakuAgent = HJDanmakuAgent.init(danmakuModel: danmaku)
                danmakuAgents.append(danmakuAgent)
            }
            danmakuAgents.sort(by: { (danmakuAgent0, danmakuAgent1) -> Bool in
                return danmakuAgent0.danmakuModel.time > danmakuAgent1.danmakuModel.time
            })
            self.semaphore.wait()
            self.danmakuAgents = danmakuAgents
            self.lastIndex = 0
            self.semaphore.signal()
        }
    }
    
    override public func fetchDanmakuAgents(forTime time: HJDanmakuTime) -> Array<HJDanmakuAgent>? {
        self.semaphore.wait()
        var lastIndex = self.lastIndex < self.danmakuAgents.count ? self.lastIndex: NSNotFound
        if lastIndex == NSNotFound {
            self.semaphore.signal()
            return nil
        }
        let lastDanmakuAgent = self.danmakuAgents[self.lastIndex]
        if time.time < lastDanmakuAgent.danmakuModel.time {
            lastIndex = 0
        }
        let minTime = CGFloat(floorf(Float(time.time * 10)) / 10.0)
        let maxTime = time.MaxTime()
        let set = IndexSet.init(integersIn: lastIndex ..< self.danmakuAgents.count)
        let indexSet = (self.danmakuAgents as NSArray).indexesOfObjects(at: set, options: .concurrent) { (agent, idx, stop) -> Bool in
            let danmakuAgent: HJDanmakuAgent = agent as! HJDanmakuAgent
            if danmakuAgent.danmakuModel.time > maxTime {
                stop.pointee = true
            }
            return danmakuAgent.remainingTime <= 0 && danmakuAgent.danmakuModel.time >= minTime && danmakuAgent.danmakuModel.time < maxTime
        }
        if indexSet.count == 0 {
            self.semaphore.signal()
            return nil
        }
        let danmakuAgents = Array.init(self.danmakuAgents[indexSet.first!...indexSet.last!])
        self.lastIndex = indexSet.first!
        self.semaphore.signal()
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
            }
            self.semaphore.wait()
            self.danmakuAgents = danmakuAgents
            self.semaphore.signal()
            completion()
        }
    }
    
    override public func sendDanmaku(_ danmaku: HJDanmakuModel, forceRender force: Bool) -> HJDanmakuAgent? {
        let danmakuAgent = HJDanmakuAgent.init(danmakuModel: danmaku)
        danmakuAgent.force = force
        self.semaphore.wait()
        self.danmakuAgents.append(danmakuAgent)
        self.semaphore.signal()
        
        return danmakuAgent
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
                    self.semaphore.wait()
                    self.danmakuAgents.append(contentsOf: danmakuAgents)
                    self.semaphore.signal()
                    danmakuAgents.removeAll()
                }
            }
        }
    }
    
    override public func fetchDanmakuAgents(forTime time: HJDanmakuTime) -> Array<HJDanmakuAgent>? {
        self.semaphore.wait()
        let danmakuAgents = NSArray.init(array: self.danmakuAgents) as! Array<HJDanmakuAgent>
        self.danmakuAgents.removeAll()
        self.semaphore.signal()
        return danmakuAgents
    }
    
}
