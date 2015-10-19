//
//  ViewController.swift
//  Illuminator
//
//  Created by kviksilver on 10/15/2015.
//  Copyright (c) 2015 kviksilver. All rights reserved.
//

import UIKit
import IlluminatorBridge

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        _ = XCTUIBridge.register("showAlert") {
            self.showAlert()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func buttonPressed(sender: AnyObject) {
        showAlert()
    }
    
    func showAlert() {
        let alert = UIAlertView(title: "Alert", message: "alert", delegate: nil, cancelButtonTitle: nil, otherButtonTitles: "OK")
        alert.show()
    }
}

