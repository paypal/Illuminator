//
//  PPAutomationBridge.m
//  PPHCore
//
//  Created by Erceg,Boris on 10/8/13.
//  Copyright 2013 PayPal. All rights reserved.
//

#ifdef DEBUG

#import "PPAutomationBridge.h"

#define PPUIABSTRINGIFY(x) #x
#define PPUIABTOSTRING(x) PPUIABSTRINGIFY(x)

@interface PPAutomationBridgeAction ()

+ (instancetype)actionWithDictionary:(NSDictionary *)dictionary;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPAutomationBridge() <
NSNetServiceDelegate,
NSStreamDelegate>

@property (nonatomic, strong, readwrite) NSNetService *server;

//streams
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSMutableData *inputData;
@property (nonatomic, strong) NSMutableData *outputData;

@property (nonatomic, weak) id<PPAutomationBridgeDelegate> delegate;


@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPAutomationBridge

#pragma mark -
#pragma mark Init & Factory

+ (instancetype)bridge {
    static dispatch_once_t onceQueue;
    static PPAutomationBridge *bridge = nil;
    
    dispatch_once(&onceQueue, ^{ bridge = [[self alloc] init]; });
    return bridge;
}


- (id)init {
    self = [super init];
    if (self) {
        self.bonjourServicePrefix = @"UIAutomationBridge";
        self.port = 4200;
    }

    return self;
}

- (void)dealloc {
    [self stopAutomationBridge];
}



- (void)startAutomationBridgeWithDelegate:(id<PPAutomationBridgeDelegate>)delegate {
    self.delegate = delegate;
    if (self.server == nil) {
        NSString *automationUDID = nil;
#ifdef AUTOMATION_UDID
        automationUDID =  [NSString stringWithUTF8String:PPUIABTOSTRING(AUTOMATION_UDID)];
#else
        // If you're not using the AUTOMATION_UDID define, we'll get a name from the device name
        NSString *deviceName = [UIDevice currentDevice].name;
        NSCharacterSet *charactersToRemove = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
        deviceName = [[deviceName componentsSeparatedByCharactersInSet:charactersToRemove] componentsJoinedByString:@"_"];
        automationUDID = deviceName;
#endif
        if (!automationUDID || [automationUDID isEqualToString:@""]) {
            automationUDID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        }
        self.server = [[NSNetService alloc] initWithDomain:@"local."
                                                      type:@"_bridge._tcp."
                                                      name:[NSString stringWithFormat:@"%@_%@", self.bonjourServicePrefix, automationUDID]
                                                      port:self.port];
        [self.server setDelegate:self];
        
    }
    if (self.server) {
        [self.server publishWithOptions:NSNetServiceListenForConnections];
    }

}

- (void)stopAutomationBridge {
    if (self.server) {
        [self.server stop];
    }
}

- (NSDictionary *)receivedMessage:(NSString *)message {
    self.isActivated = YES;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding]
                                                    options: NSJSONReadingMutableContainers
                                                      error: nil];
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        NSMutableDictionary *returnDict = [NSMutableDictionary dictionary];
        NSDictionary *result = [self.delegate automationBridge:self receivedAction:[PPAutomationBridgeAction actionWithDictionary:jsonObject]];
        if (result) {
            [returnDict setObject:result forKey:@"result"];
        }
        [returnDict setObject:[jsonObject objectForKey:@"callUID"] forKey:@"callUID"];
        return returnDict;
    }

    return nil;
}
#pragma mark -
#pragma mark NSNetServiceDelegate

- (void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    [self setInputStream:inputStream];
    [self setOutputStream:outputStream];
}

#pragma mark -
#pragma mark helpers

- (void)answerWith:(NSDictionary *)dictionary {
    NSData *response = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:0
                                                         error:nil];
    if (response) {
        if (!self.outputData) {
            self.outputData = [[NSMutableData alloc] initWithData:response];
        } else {
            [self.outputData appendData:response];
        }
    }
    if ([_outputStream streamStatus] == NSStreamStatusOpen) {
        [self outputStream:_outputStream handleEvent:NSStreamEventHasSpaceAvailable];
    } else {
        [_outputStream open];
    }
}

- (void)setInputStream:(NSInputStream *)inputStream {
    _inputData = nil;
    if (_inputStream) {
        [_inputStream close];
        [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                forMode:NSDefaultRunLoopMode];
        _inputStream = nil;
    }
    if (inputStream) {
        _inputStream = inputStream;
        [_inputStream setDelegate:self];
        [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                forMode:NSDefaultRunLoopMode];
        [_inputStream open];
    }
}

- (void)setOutputStream:(NSOutputStream *)outputStream {
    _outputData = nil;
    if (_outputStream) {
        [_outputStream close];
        [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                forMode:NSDefaultRunLoopMode];
        _outputStream = nil;
    }
    if (outputStream) {
        _outputStream = outputStream;
        [_outputStream setDelegate:self];
        [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                 forMode:NSDefaultRunLoopMode];
    }
}



#pragma mark -
#pragma mark NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    if (stream == self.inputStream) {
        [self inputStream:(NSInputStream*)stream handleEvent:eventCode];
    } else if (stream == self.outputStream) {
        [self outputStream:stream handleEvent:eventCode];
    }
}

- (void)inputStream:(NSInputStream *)stream handleEvent:(NSStreamEvent)eventCode {

    switch(eventCode) {
        case NSStreamEventHasBytesAvailable: {
            if (!self.inputData) {
                self.inputData = [NSMutableData data];
            }

            while (stream.hasBytesAvailable) {
                uint8_t buffer[32768];
                NSInteger len = 0;
                len = [(NSInputStream *)stream read:buffer maxLength:sizeof(buffer)];
                if(len) {
                    [self.inputData appendBytes:(const void *)buffer length:len];
                }
            }
            NSInteger jsonMessageLength;
            do {
                jsonMessageLength = [self findJsonMessage];
                if (jsonMessageLength > 0) {
                    NSString* json = [[NSString alloc] initWithBytes:self.inputData.bytes length:jsonMessageLength encoding:NSASCIIStringEncoding];
                    [self.inputData replaceBytesInRange:NSMakeRange(0, jsonMessageLength) withBytes:nil length:0];
                    [self answerWith:[self receivedMessage:json]];
                }
            } while (jsonMessageLength > 0);
            break;
        }
        default:
            break;
    }

}

- (void)outputStream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch(eventCode) {
        case NSStreamEventHasSpaceAvailable: {
            const uint8_t *pData = [self.outputData bytes];
            while ([self.outputStream hasSpaceAvailable] && self.outputData.length > 0) {
                NSInteger r = [self.outputStream write:pData maxLength:self.outputData.length];
                if (r == -1) {
                    break;
                }
                [self.outputData replaceBytesInRange:NSMakeRange(0, r) withBytes:nil length:0];
            }
            break;
        case NSStreamEventEndEncountered:
            self.outputStream = nil;
            break;
        case NSStreamEventErrorOccurred:
            break;
        default:
            break;
        }
    }

}

/**
 Figure out if we have a fully formed JSON message in our buffer. Bad JSON will confuse this, and this is not
 intended to be a true parser. It just finds out if we have a complete message assuming well formed-ness.
 */
- (NSInteger)findJsonMessage {
    int count = 0;
    const uint8_t *bytes = [self.inputData bytes];
    for (long i = 0, len = self.inputData.length; i < len; i++) {
        char c = bytes[i];
        switch (c) {
            case '{': case '[':
                count++;
                break;
            case '}': case ']':
                if (count == 1) {
                    // Found the end.
                    return i+1;
                }
                count--;
                break;
            case '\"':
            {
                NSInteger tokenLength = [self readJsonString: i];
                if (tokenLength == -1) {
                    return -1;
                }
                i += tokenLength;
                break;
            }
        }
    }
    return -1;
}

- (NSInteger)readJsonString:(NSInteger) start {
    const uint8_t *bytes = [self.inputData bytes];
    for (long i = start+1, len = self.inputData.length; i < len; i++) {
        char c = bytes[i];
        if (c == '\"') {
            // Found the end of the string
            return i-start;
        }
        if (c == '\\') {
            i++;
        }
    }
    return -1;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPAutomationBridgeAction

+ (instancetype)actionWithDictionary:(NSDictionary *)dictionary {
    PPAutomationBridgeAction *action = [PPAutomationBridgeAction new];
    [action setSelector:[dictionary objectForKey:@"selector"]];
    if ([dictionary objectForKey:@"argument"]) {
        [action setArguments:[dictionary objectForKey:@"argument"]];
    }
    return action;
}

- (NSDictionary *)resultFromTarget:(id)target {
    SEL selector = NSSelectorFromString(self.selector);
    if ([target respondsToSelector:selector]) {
        id result = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        if (self.arguments) {
            result = [target performSelector:selector withObject:self.arguments];
        } else {
            result = [target performSelector:selector];
        }
#pragma clang diagnostic pop
        return result;
    } else {
        return nil;
    }
}

@end

#endif
