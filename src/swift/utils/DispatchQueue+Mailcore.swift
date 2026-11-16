//
//  DispatchQueue+Readdle.swift
//  mailcore2
//
//  Created by Andrew on 9/12/17.
//  Copyright © 2017 MailCore. All rights reserved.
//

import Foundation
import Dispatch

#if os(Android) || os(Windows) || os(Linux)
    import CDispatch
    
    typealias CDispatchQueue = dispatch_queue_t
    
    fileprivate class _DispatchQueue {
        let __wrapped: CDispatchQueue
        
        init(queue: CDispatchQueue) {
            __wrapped = queue
        }
    }
#else
    typealias CDispatchQueue = DispatchQueue // dispatch_queue_t is unavailable in Swift iOS/macOS
#endif

extension DispatchQueue {
    
    class func queueFromWrapped(_ cdispatch: CDispatchQueue) -> DispatchQueue {
        #if os(Android) || os(Windows) || os(Linux)
            return unsafeBitCast(_DispatchQueue(queue: cdispatch), to: DispatchQueue.self)
        #else
            return cdispatch
        #endif
    }
    
    var wrapped: CDispatchQueue {
        #if os(Android) || os(Windows) || os(Linux)
            return unsafeBitCast(self, to: _DispatchQueue.self).__wrapped
        #else
            return self
        #endif
    }
    
    
}
