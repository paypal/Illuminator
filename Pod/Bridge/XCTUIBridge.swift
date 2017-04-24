//
//  XCTUIBridge.swift
//  Bridge
//
//  Created by Boris Erceg on 29/09/15.
//
//

import Foundation

public typealias XCTUIBridgeRemover = () -> Void;
public typealias XCTUIBridgeCallback = () -> Void;

private let instance = XCTUIBridge()

private class XCTUIBridgeCallbackContainer {
    let completion:XCTUIBridgeCallback
    init(completion: @escaping XCTUIBridgeCallback) {
        self.completion = completion
    }
}

open class XCTUIBridge: NSObject {
    
    fileprivate var clientListeners = [String: NSMutableArray]();
    
    func notificationRecieved(_ name:String) {
        if let listeners = clientListeners[name] {
            for i in 0..<listeners.count {
                (listeners.object(at: i) as? XCTUIBridgeCallbackContainer)?.completion()
            }
        }
    }
    
    static open func sendNotification(_ identifier: String) {
        let notificationName = CFNotificationName(rawValue: identifier as CFString)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, nil, nil, true)
    }
    
    
    static open func register(_ identifier: String, completion: @escaping XCTUIBridgeCallback) -> XCTUIBridgeRemover {
        if let _ = instance.clientListeners[identifier] {
            let container = XCTUIBridgeCallbackContainer(completion: completion)
            instance.clientListeners[identifier]!.add(container)
            let remover:XCTUIBridgeRemover = {
                instance.clientListeners[identifier]!.remove(container)
            }
            return remover
        } else {
            instance.clientListeners[identifier] = NSMutableArray()
            registerForDarwinNotification(identifier)
            return register(identifier, completion: completion)
        }
    }
    
    static fileprivate func registerForDarwinNotification(_ identifier: String) {
        let callback: @convention(block) (CFNotificationCenter?, UnsafeMutableRawPointer, CFString?, UnsafeRawPointer, CFDictionary?) -> Void = { (center, observer, name, object, userInfo) in
            instance.notificationRecieved(identifier)
        }
        
        let imp: OpaquePointer = imp_implementationWithBlock(unsafeBitCast(callback, to: AnyObject.self))
        let notificationCallback = unsafeBitCast(imp, to: CFNotificationCallback.self)
        
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged<AnyObject>.passUnretained(self).toOpaque(), notificationCallback, identifier as CFString, nil, .deliverImmediately)
    }
    
}
