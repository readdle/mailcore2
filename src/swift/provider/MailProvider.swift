//
//  MCOMailProvider.swift
//  mailcore2
//
//  Created by Andrew on 7/26/17.
//  Copyright © 2017 MailCore. All rights reserved.
//

import Foundation

public class MCOMailProvider: NSObject, Convertible {
    
    internal var nativeInstance: CMailProvider
    
    required public init(mailCoreObject: CObject) {
        self.nativeInstance = CMailProvider(cobject: mailCoreObject)
        self.nativeInstance.retain()
    }
    
    deinit {
        self.nativeInstance.release()
    }
    
    func cast() -> CObject {
        return nativeInstance.toCObject()
    }
    
    public var imapServices: [MCONetService] {
        return Array<MCONetService>.cast(self.nativeInstance.imapServices)
    }
    
    public var smtpServices: [MCONetService] {
        return Array<MCONetService>.cast(self.nativeInstance.smtpServices)
    }

    
}