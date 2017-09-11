//
//  HJDanmakuSource.swift
//  Pods
//
//  Created by haijiao on 2017/9/11.
//
//

import Foundation

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
    
    override public func prepareDanmakus(_ danmakus: Array<HJDanmakuModel>, completion: @escaping () -> Swift.Void) {
        
    }
    
}

public class HJDanmakuLiveSource: HJDanmakuSource {
    
    override public func prepareDanmakus(_ danmakus: Array<HJDanmakuModel>, completion: @escaping () -> Swift.Void) {
        onGlobalThreadAsync {
            var danmakuAgents = Array<HJDanmakuAgent>.init()
            for danmaku in danmakus {
                let agent = HJDanmakuAgent.init(danmakuModel: danmaku)
                danmakuAgents.append(agent)
                OSSpinLockLock(&self.spinLock);
                self.danmakuAgents = danmakuAgents
                OSSpinLockUnlock(&self.spinLock);
                completion()
            }
        }
    }
    
    override public func sendDanmaku(_ danmaku: HJDanmakuModel, forceRender force: Bool) {
        let danmakuAgent = HJDanmakuAgent.init(danmakuModel: danmaku)
        danmakuAgent.force = force
        OSSpinLockLock(&self.spinLock);
        self.danmakuAgents.append(danmakuAgent)
        OSSpinLockUnlock(&self.spinLock);
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
                    OSSpinLockLock(&self.spinLock);
                    self.danmakuAgents.append(contentsOf: danmakuAgents)
                    OSSpinLockUnlock(&self.spinLock);
                    danmakuAgents.removeAll()
                }
            }
        }
    }
    
    override public func fetchDanmakuAgents(forTime time: HJDanmakuTime) -> Array<HJDanmakuAgent>? {
        OSSpinLockLock(&self.spinLock);
        let danmakuAgents = NSArray.init(array: self.danmakuAgents) as! Array<HJDanmakuAgent>
        self.danmakuAgents.removeAll()
        OSSpinLockUnlock(&self.spinLock);
        return danmakuAgents
    }
    
}
