
The ILLUMINATOR Bridge
======================

Some states can't be easily reproduced in simulation.  For example, hardware components (like credit card readers or cameras), app-launch behavior, app minimizing behavior, backend network request manipulation, and the precise timing of various permission or network requests are difficult to simulate reliably and repeatably through Javascript alone.

For these, the Illuminator Bridge is needed; it allows you to pass JSON to and from your application.

Bridge API Documentation in docset format can be found in docs folder.


Integrating a Bridge Call into Your Application
--------------------------------------------

1. Add `PPAutomationBridge` class to your project
2. Make an object that conforms to `PPAutomationBridgeDelegate` protocol
3. Implement `automationBridge:receivedAction:` method (if you want default implementation see `PPAutomationBridgeDelegate` example in sample app)
4. Start your bridge with `startAutomationBridgeWithDelegate:`

In this example, we'll fake the operation of a barcode scanner by adding a bridge call for `fakeBarcodeScan`.  This will return a dummy piece of data for illustrative purposes.

```objective-c

- (NSDictionary *)fakeBarcodeScan:(NSDictionary *)parameters {
    NSString *dummy = [dummy dummy:parameters[@"barcode"]];
    return @{@"dummy":dummy};
}

```


Integrating a Bridge Call into Your Tests
-----------------------------------------

Making action functions directly from Bridge call selectors is the preferred way to do this.

```javascript

myScreen // some screen you've already defined in your app
    .withAction("scanBarcode", "Fake a scan of a barcode")
    .withImplementation(bridge.makeActionFunction("fakeBarcodeScan:"))
    .withParam("barcode", "The barcode string to fake", false, true)

```


The other way to do it (as part of a larger function) would be as follows:

```javascript

function myFakeBarcodeScanAction(parm) {
    // anything you need to do before the bridge call

    // manually call the bridge
    var result = bridge.runNativeMethod("fakeBarcodeScan:", {"barcode": parm.barcode});

    // anything you need to do after the bridge call, such as validating the result
    if (result.dummy === undefined || result.dummy == "banana") {
       throw new IlluminatorRuntimeVerificationException("Who puts barcodes on a banana anyway?");
    }
}

myScreen // some screen you've already defined in your app
    .withAction("scanBarcode", "Fake a scan of a barcode")
    .withImplementation(myFakeBarcodeScanAction)
    .withParam("barcode", "The barcode string to fake", false, true)

```
