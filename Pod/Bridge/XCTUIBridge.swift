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
    init(completion: XCTUIBridgeCallback) {
        self.completion = completion
    }
}

public class XCTUIBridge: NSObject {
    
    private var clientListeners = [String: NSMutableArray]();
    
    func notificationRecieved(name:String) {
        if let listeners = clientListeners[name] {
            for var i = 0; i < listeners.count; i++ {
                (listeners.objectAtIndex(i) as? XCTUIBridgeCallbackContainer)?.completion()
            }
        }
    }
    
    static public func sendNotification(identifier: String) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), identifier as CFString, nil, nil, true)
    }
    
    
    static public func register(identifier: String, completion: XCTUIBridgeCallback) -> XCTUIBridgeRemover {
        if let _ = instance.clientListeners[identifier] {
            let container = XCTUIBridgeCallbackContainer(completion: completion)
            instance.clientListeners[identifier]!.addObject(container)
            let remover:XCTUIBridgeRemover = {
                instance.clientListeners[identifier]!.removeObject(container)
            }
            return remover
        } else {
            instance.clientListeners[identifier] = NSMutableArray()
            registerForDarwinNotification(identifier)
            return register(identifier, completion: completion)
        }
    }
    
    static private func registerForDarwinNotification(identifier: String) {
        let callback: @convention(block) (CFNotificationCenter!, UnsafeMutablePointer<Void>, CFString!, UnsafePointer<Void>, CFDictionary!) -> Void = { (center, observer, name, object, userInfo) in
            instance.notificationRecieved(identifier)
        }
        
        let imp: COpaquePointer = imp_implementationWithBlock(unsafeBitCast(callback, AnyObject.self))
        let notificationCallback = unsafeBitCast(imp, CFNotificationCallback.self)
        
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), unsafeAddressOf(self), notificationCallback, identifier, nil, .DeliverImmediately)
    }
    
}