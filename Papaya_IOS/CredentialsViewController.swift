//
//  CredentialsViewController.swift
//  PapayaSwift
//
//  Created by Karim Abedrabbo on 8/15/18.
//  Copyright © 2018 Papaya. All rights reserved.
//

import UIKit
import CoreBluetooth
import LocalAuthentication
import AudioToolbox

// Conform to CBCentralManagerDelegate, CBPeripheralDelegate protocols
class CredentialsViewController: UIViewController {
    
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardDismissRecognizer()
        
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupKeyboardDismissRecognizer(){
        let tapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(self.dismissKeyboard))
        
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    @objc func dismissKeyboard()
    {
        view.endEditing(true)
    }
    
    
    @IBAction func saveCreds(_ sender: Any) {
        let defaults = UserDefaults.standard
        defaults.set(" " + usernameField.text! + " " + passwordField.text! + " ", forKey: "Credentials")
        
        let randomkey = randomString(length:256);
        
        defaults.set(randomkey, forKey: "crypkey")
        defaults.synchronize()
        
    self.navigationController?.popViewController(animated: true)
    }
    
    func randomString(length: Int) -> String {
        
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let len = UInt32(letters.length)
        
        var randomString = ""
        
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        
        return randomString
    }
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}




