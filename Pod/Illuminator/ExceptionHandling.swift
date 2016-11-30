//
//  ExceptionHandling.swift
//  Pods
//
//  Created by Erceg, Boris on 26/10/15.
//
//

import Foundation

public func pcall(tryBlock:IlluminatorEmptyBlock, catchBlock:IlluminatorExceptionBlock? = nil, finally:IlluminatorEmptyBlock? = nil) {
    NSObject.protectedSwiftCall(tryBlock, catchBlock: catchBlock, finally: finally)
}
