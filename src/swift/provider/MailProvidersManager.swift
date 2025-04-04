//
//  CMailProvidersManager.swift
//  mailcore2
//
//  Created by Andrew on 7/26/17.
//  Copyright © 2017 MailCore. All rights reserved.
//

import Foundation
import CMailCore

public class MCOMailProvidersManager: NSObjectCompat {
    
    public static let sharedManager = MCOMailProvidersManager()
    
    private override init() {
        super.init()

        #if !os(Android) && !os(Windows)
        let filename: String?
        #if SWIFT_PACKAGE
        filename = Bundle.module.path(forResource: "providers", ofType: "json")
        #else
        filename = Bundle(for: MCOMailProvidersManager.self).path(forResource: "providers", ofType: "json")
        #endif
        if let filename = filename {
            MCOMailProvidersManager.registerProviders(filename: filename)
        }
        #endif
    }

    public static func registerProviders(filename: String) {
        mailCoreAutoreleasePool {
            CMailProvidersManager_shared().registerProvidersWithFilename(filename.mailCoreString())
        }
    }
    
    public func provider(forEmail: String) -> MCOMailProvider? {
        return mailCoreAutoreleasePool {
            createMCOObject(from: CMailProvidersManager_shared().providerForEmail(forEmail.mailCoreString()).toCObject())
        }
    }
    
    public func provider(forMX: String) -> MCOMailProvider? {
        return mailCoreAutoreleasePool {
            createMCOObject(from: CMailProvidersManager_shared().providerForMX(forMX.mailCoreString()).toCObject())
        }
    }
    
    public func provider(forIdentifier: String) -> MCOMailProvider? {
        return mailCoreAutoreleasePool {
            createMCOObject(from: CMailProvidersManager_shared().providerForIdentifier(forIdentifier.mailCoreString()).toCObject())
        }
    }
}
