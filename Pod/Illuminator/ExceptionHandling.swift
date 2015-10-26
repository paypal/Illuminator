//
//  ExceptionHandling.swift
//  Pods
//
//  Created by Erceg, Boris on 26/10/15.
//
//

import Foundation

public func tryBlock(tryBlock:IlluminatorEmptyBlock, catchBlock:IlluminatorExceptionBlock? = nil, finally:IlluminatorEmptyBlock? = nil) {
    NSObject.tryBlock(tryBlock, catchBlock: catchBlock, finally:finally)
}

public func throwException(exception: NSException) {
    NSObject.throwException(exception)
}