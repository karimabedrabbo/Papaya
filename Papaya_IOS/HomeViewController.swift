//
//  HomeViewController.swift
//  PapayaSwift
//
//  Created by Karim Abedrabbo on 8/15/18.
//  Copyright © 2018 Papaya. All rights reserved.
//

import UIKit
import CoreBluetooth
import LocalAuthentication
import AudioToolbox
import UserNotifications


// Conform to CBCentralManagerDelegate, CBPeripheralDelegate protocols
class HomeViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var backgroundImageView1: UIImageView!
    @IBOutlet weak var backgroundImageView2: UIImageView!
    @IBOutlet weak var controlContainerView: UIView!
    @IBOutlet weak var circleView: UIView!
    @IBOutlet weak var firstLabel: UILabel!
    @IBOutlet weak var secondLabel: UILabel!
    
    // define our scanning interval times
    let timerPauseInterval:TimeInterval = 0.2
    let timerScanInterval:TimeInterval = 2.0

    let RSSICaptureOverInterval: TimeInterval = 0.5
    var RSSICounter = 0
    
    var isReady: Bool {
        get {
            return Papaya != nil &&
                serialCharacteristic != nil
        }
    }
    
    // UI-related
    let firstLabelFontName = "HelveticaNeue-Thin"
    let firstLabelFontSizeMessage:Double = 56.0
    let firstLabelFontSizeTemp:Double = 81.0
    
    var backgroundImageViews: [UIImageView]!
    var visibleBackgroundIndex = 0
    var invisibleBackgroundIndex = 1
    
    var prevRSSI: Double = -1000.0
    var currRSSI: Double = -1000.0
    //var RSSIList: [Double] = []
    
    var distance: Double = 0.0

    var circleDrawn = false
    var keepScanning = false
    var keepUpdatingRSSI = false
    var singleAuthenticate = false
    var backgroundSingleAuthenticate = false
    var allowNotifications = false
    //var isScanning = false
    
    // Core Bluetooth properties
    var centralManager:CBCentralManager!
    var Papaya:CBPeripheral?
    
    weak var serialCharacteristic: CBCharacteristic?
    weak var commandCharacteristic: CBCharacteristic?
    
    /// Whether to write to the HM10 with or without response. Set automatically.
    /// Legit HM10 modules (from JNHuaMao) require 'Write without Response',
    /// while fake modules (e.g. from Bolutek) require 'Write with Response'.
    private var writeType: CBCharacteristicWriteType = .withoutResponse
    
    let PapayaName = "Bluno"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 10.0, *) {
            
            // Configure User Notification Center
            UNUserNotificationCenter.current().delegate = self
            
            // Request Notification Settings
            UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
                switch notificationSettings.authorizationStatus {
                case .notDetermined:
                    self.requestAuthorization(completionHandler: { (success) in
                        guard success else { return }
                        
                        // Schedule Local Notification
                        self.allowNotifications = true
                    })
                case .authorized:
                    // Schedule Local Notification
                    self.allowNotifications = true
                case .denied:
                    print("Application Not Allowed to Display Notifications")
                case .provisional:
                    print("Application Not Allowed to Display Notifications")
              }
            }
        }
        
        
        // Create our CBCentral Manager
        // delegate: The delegate that will receive central role events. Typically self.
        // queue:    The dispatch queue to use to dispatch the central role events. 
        //           If the value is nil, the central manager dispatches central role events using the main queue.
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Central Manager Initialization Options (Apple Developer Docs): http://tinyurl.com/zzvsgjh
        //  CBCentralManagerOptionShowPowerAlertKey
        //  CBCentralManagerOptionRestoreIdentifierKey
        //      To opt in to state preservation and restoration in an app that uses only one instance of a 
        //      CBCentralManager object to implement the central role, specify this initialization option and provide
        //      a restoration identifier for the central manager when you allocate and initialize it.
        //centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        // configure initial UI
        firstLabel.font = UIFont(name: firstLabelFontName, size: CGFloat(firstLabelFontSizeMessage))
        firstLabel.text = "Searching"
        secondLabel.text = ""
        secondLabel.isHidden = true
        circleView.isHidden = true
        backgroundImageViews = [backgroundImageView1, backgroundImageView2]
        view.bringSubview(toFront: backgroundImageViews[0])
        backgroundImageViews[0].alpha = 1
        backgroundImageViews[1].alpha = 0
        view.bringSubview(toFront: controlContainerView)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {

        self.navigationController?.setNavigationBarHidden(true, animated: true)
        super.viewWillAppear(true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        super.viewWillDisappear(true)
        
    }
    
    // MARK: - Private Methods
    
    private func requestAuthorization(completionHandler: @escaping (_ success: Bool) -> ()) {
        // Request Authorization
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (success, error) in
                if let error = error {
                    print("Request Authorization Failed (\(error), \(error.localizedDescription))")
                }
                
                completionHandler(success)
            }
        }
    }
    
    


    
    // MARK: - Bluetooth scanning
    
    @objc func pauseScan() {
        // Scanning uses up battery on phone, so pause the scan process for the designated interval.
        print("*** PAUSING SCAN...")
        _ = Timer.scheduledTimer(timeInterval: timerPauseInterval, target: self, selector: #selector(resumeScan), userInfo: nil, repeats: false)
        centralManager.stopScan()
    }
    
    @objc func resumeScan() {
        if keepScanning {
            // Start scanning again...
            print("*** RESUMING SCAN!")
            firstLabel.font = UIFont(name: firstLabelFontName, size: CGFloat(firstLabelFontSizeMessage))
            firstLabel.text = "Searching"
            _ = Timer.scheduledTimer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            let PapayaAdvertisingUUID = CBUUID(string: Device.AdvertisingUUID)
            centralManager.scanForPeripherals(withServices: [PapayaAdvertisingUUID], options: nil)
        }
    }
    
    
    // MARK: - Updating UI

    func drawCircle() {
        circleView.isHidden = false
        let circleLayer = CAShapeLayer()
        circleLayer.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: circleView.frame.width, height: circleView.frame.height)).cgPath
        circleView.layer.addSublayer(circleLayer)
        circleLayer.lineWidth = 2
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.fillColor = UIColor.clear.cgColor
        circleDrawn = true
    }
    
    func RSSIToFilename(RSSI:Double) -> Int {
        
        var RSSITens = 10;
        if (distance < 2.0) {
            RSSITens = 100;
        } else if (distance < 3.0) {
            RSSITens = 90;
        } else if (distance < 4.0) {
            RSSITens = 80;
        } else if (distance < 5.0) {
            RSSITens = 70;
        } else if (distance < 6.0) {
            RSSITens = 60;
        } else if (distance < 7.0) {
            RSSITens = 50;
        } else if (distance < 8.0) {
            RSSITens = 40;
        } else if (distance < 9.0) {
            RSSITens = 30;
        } else if (distance < 10.0) {
            RSSITens = 20;
        }
        return RSSITens
    }
    
    func updateBackgroundImageForRSSI(RSSIFrom:Double) {
            // generate file name of new background to show
        let calculatedRSSIFilename = RSSIToFilename(RSSI: RSSIFrom)
            let RSSIFilename = "temp-\(calculatedRSSIFilename)"
            print("*** BACKGROUND FILENAME: \(RSSIFilename)")
            
            // fade out old background, fade in new.
            let visibleBackground = backgroundImageViews[visibleBackgroundIndex]
            let invisibleBackground = backgroundImageViews[invisibleBackgroundIndex]
            invisibleBackground.image = UIImage(named: RSSIFilename)
            invisibleBackground.alpha = 0
            view.bringSubview(toFront: invisibleBackground)
            view.bringSubview(toFront: controlContainerView)
            invisibleBackground.alpha = 1;
            visibleBackground.alpha = 0
            let indexTemp = self.visibleBackgroundIndex
            self.visibleBackgroundIndex = self.invisibleBackgroundIndex
            self.invisibleBackgroundIndex = indexTemp
            print("**** NEW INDICES - visible: \(self.visibleBackgroundIndex) - invisible: \(self.invisibleBackgroundIndex)")
//            UIView.animate(withDuration: 0.3, animations: {
//                    invisibleBackground.alpha = 1;
//                }, completion: { (finished) in
//                    visibleBackground.alpha = 0
//                    let indexTemp = self.visibleBackgroundIndex
//                    self.visibleBackgroundIndex = self.invisibleBackgroundIndex
//                    self.invisibleBackgroundIndex = indexTemp
//                    print("**** NEW INDICES - visible: \(self.visibleBackgroundIndex) - invisible: \(self.invisibleBackgroundIndex)")
//            })
        
    }
    
    @objc func updateDisplayCheckAuthentication() {
        if UIApplication.shared.applicationState == .active && keepUpdatingRSSI {
            if !circleDrawn {
                drawCircle()
            } else {
                circleView.isHidden = false
            }
            
            Papaya?.readRSSI()
            
            var averagedRSSI: Double = 0.0
            if RSSICounter < 2 {
                averagedRSSI = average(arr: [currRSSI, prevRSSI])
            } else {
                
                averagedRSSI = currRSSI
            }
            
            
            //print("List Count:" + String(describing: RSSIList.count))
            //print("averagedRSSI: " + String(describing: averagedRSSI))
            updateBackgroundImageForRSSI(RSSIFrom: averagedRSSI)
            firstLabel.font = UIFont(name: firstLabelFontName, size: CGFloat(firstLabelFontSizeTemp))
            let roundedDistance: Int = Int(round(distance))
            firstLabel.text = " \(roundedDistance)"
            
            if currRSSI > -62 && prevRSSI > -62 && singleAuthenticate == false {
                self.authenticationWithTouchID()
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                singleAuthenticate = true
            } else if currRSSI <= -62 && prevRSSI <= -62 {
                singleAuthenticate = false
            }
        }
    }
    
    

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if RSSICounter > 0 {
            prevRSSI = currRSSI
        }
        currRSSI = RSSI as! Double
        
        distance = RSSIToDistance(rssiValue: currRSSI)
        
        RSSICounter += 1
        print(RSSICounter)
        
//        if RSSIList.count < Int(RSSICaptureOverInterval/(updateRSSIInterval)) {
//            RSSIList.append(currRSSI)
//        } else {
//            RSSIList.removeFirst()
//            RSSIList.append(currRSSI)
//        }
    }
    
    func interquartileMean(arr: [Double]) -> Double {
        let lowerBound = Int(round(0.25 * Double(arr.count)))
        let upperBound = Int(round(0.75 * Double(arr.count)))
        let sortedArray = arr.sorted(by: <)
        var runningTotal: Double = 0.0
        
        for i in lowerBound ..< upperBound {
            runningTotal += sortedArray[i]
        }
       
        return Double(runningTotal / Double((upperBound - lowerBound)))
    }
    
    func average(arr: [Double]) -> Double {
        let sumArray = arr.reduce(0, +)
        let avgArrayValue = Double(sumArray) / Double(arr.count)
        
        return avgArrayValue
    }
    

    // MARK: - CBCentralManagerDelegate methods
    
    // Invoked when the central manager’s state is updated.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var showAlert = true
        var message = ""
        
        switch central.state {
        case .poweredOff:
            message = "Bluetooth on this device is currently powered off."
        case .unsupported:
            message = "This device does not support Bluetooth Low Energy."
        case .unauthorized:
            message = "This app is not authorized to use Bluetooth Low Energy."
        case .resetting:
            message = "The BLE Manager is resetting; a state update is pending."
        case .unknown:
            message = "The state of the BLE Manager is unknown."
        case .poweredOn:
            showAlert = false
            message = "Bluetooth LE is turned on and ready for communication."
    
            print(message)
            
            keepScanning = true
                
            _ = Timer.scheduledTimer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            
            // Initiate Scan for Peripherals
            //Option 1: Scan for all devices
            //centralManager.scanForPeripherals(withServices: nil, options: nil)
            
            // Option 2: Scan for devices that have the service you're interested in...
            let PapayaAdvertisingUUID = CBUUID(string: Device.AdvertisingUUID)
            print("Scanning for Papaya adverstising with UUID: \(PapayaAdvertisingUUID)")
            centralManager.scanForPeripherals(withServices: [PapayaAdvertisingUUID], options: nil)

        }
        
        if showAlert {
            let alertController = UIAlertController(title: "Central Manager State", message: message, preferredStyle: UIAlertControllerStyle.alert)
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil)
            alertController.addAction(okAction)
            self.show(alertController, sender: self)
        }
    }
    
    
    /*
     Invoked when the central manager discovers a peripheral while scanning.
     
     The advertisement data can be accessed through the keys listed in Advertisement Data Retrieval Keys. 
     You must retain a local copy of the peripheral if any command is to be performed on it. 
     In use cases where it makes sense for your app to automatically connect to a peripheral that is 
     located within a certain range, you can use RSSI data to determine the proximity of a discovered 
     peripheral device.
     
     central - The central manager providing the update.
     peripheral - The discovered peripheral.
     advertisementData - A dictionary containing any advertisement data.
     RSSI - The current received signal strength indicator (RSSI) of the peripheral, in decibels.

     */
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        //print("centralManager didDiscoverPeripheral - CBAdvertisementDataLocalNameKey is \"\(CBAdvertisementDataLocalNameKey)\"")
        
        // Retrieve the peripheral name from the advertisement data using the "kCBAdvDataLocalName" key
        if let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
//            print("NEXT PERIPHERAL NAME: \(peripheralName)")
//            print("NEXT PERIPHERAL UUID: \(peripheral.identifier.uuid)")
//
            if peripheralName == PapayaName {
                print("*** PAPAYA FOUND ADDING NOW ***")
                // to save power, stop scanning for other devices
                keepScanning = false
                
                // save a reference to the papaya
                Papaya = peripheral
                Papaya!.delegate = self
                
                // Request a connection to the peripheral
                centralManager.connect(Papaya!, options: [CBConnectPeripheralOptionNotifyOnNotificationKey: true, CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
            }
        }
    }
    
    
    /*
     Invoked when a connection is successfully created with a peripheral.
     
     This method is invoked when a call to connectPeripheral:options: is successful. 
     You typically implement this method to set the peripheral’s delegate and to discover its services.
    */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("**** SUCCESSFULLY CONNECTED TO PAPAYA ***")
    
        firstLabel.font = UIFont(name: firstLabelFontName, size: CGFloat(firstLabelFontSizeMessage))
        firstLabel.text = "Connected"
        
        // Now that we've successfully connected to the Papaya, let's discover the services.
        // - NOTE:  we pass nil here to request ALL services be discovered.
        //          If there was a subset of services we were interested in, we could pass the UUIDs here.
        //          Doing so saves battery life and saves time.
        peripheral.discoverServices([CBUUID(string: Device.AdvertisingUUID)])
        
        keepUpdatingRSSI = true
        

        _ = Timer.scheduledTimer(timeInterval: RSSICaptureOverInterval, target: self, selector: #selector(updateDisplayCheckAuthentication), userInfo: nil, repeats: true)
    }
    
    
    /*
     Invoked when the central manager fails to create a connection with a peripheral.

     This method is invoked when a connection initiated via the connectPeripheral:options: method fails to complete. 
     Because connection attempts do not time out, a failed connection usually indicates a transient issue, 
     in which case you may attempt to connect to the peripheral again.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("**** CONNECTION TO PAPAYA FAILED ***")
    }
    

    /*
     Invoked when an existing connection with a peripheral is torn down.
     
     This method is invoked when a peripheral connected via the connectPeripheral:options: method is disconnected. 
     If the disconnection was not initiated by cancelPeripheralConnection:, the cause is detailed in error. 
     After this method is called, no more methods are invoked on the peripheral device’s CBPeripheralDelegate object.
     
     Note that when a peripheral is disconnected, all of its services, characteristics, and characteristic descriptors are invalidated.
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("**** DISCONNECTED FROM PAPAYA ***")

        keepUpdatingRSSI = false
        
        circleView.isHidden = true
        firstLabel.font = UIFont(name: firstLabelFontName, size: CGFloat(firstLabelFontSizeMessage))
        firstLabel.text = "Searching"
        secondLabel.text = ""
        secondLabel.isHidden = true
        if error != nil {
            print("****** DISCONNECTION DETAILS: \(error!.localizedDescription)")
        }
        centralManager.connect(Papaya!, options: [CBConnectPeripheralOptionNotifyOnNotificationKey: true, CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
    }
    
    
    //MARK: - CBPeripheralDelegate methods
    
    /*
     Invoked when you discover the peripheral’s available services.
     
     This method is invoked when your app calls the discoverServices: method. 
     If the services of the peripheral are successfully discovered, you can access them 
     through the peripheral’s services property. 
     
     If successful, the error parameter is nil. 
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    // When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            print("ERROR DISCOVERING SERVICES: \(String(describing: error?.localizedDescription))")
            return
        }

        // Core Bluetooth creates an array of CBService objects —- one for each service that is discovered on the peripheral.
        if let services = peripheral.services {
            for service in services {
                print("Discovered service \(service)")
                // If we found either the Serial or the Command service, discover the characteristics for those services.
                if (service.uuid == CBUUID(string: Device.AdvertisingUUID)) {
                    peripheral.discoverCharacteristics([CBUUID(string: Device.SerialPortUUID), CBUUID(string: Device.CommandUUID)], for: service)
                }
            }
        }
    }
    
    
    /*
     Invoked when you discover the characteristics of a specified service.
     
     If the characteristics of the specified service are successfully discovered, you can access
     them through the service's characteristics property. 
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print("ERROR DISCOVERING CHARACTERISTICS: \(String(describing: error?.localizedDescription))")
            return
        }
        
        if let characteristics = service.characteristics {
            //var enableValue:UInt8 = 1
            //let enableBytes = NSData(bytes: &enableValue, length: MemoryLayout<UInt8>.size)

            for characteristic in characteristics {
                // Serial Data Characteristic
                print("Discovered service \(characteristic)")
                if characteristic.uuid == CBUUID(string: Device.SerialPortUUID) {
                    // Enable the Serial notifications
                    serialCharacteristic = characteristic
                    Papaya?.setNotifyValue(true, for: characteristic)
                }
                
                
                if characteristic.uuid == CBUUID(string: Device.CommandUUID) {
                    // Enable Command notifications
                    commandCharacteristic = characteristic
                    Papaya?.setNotifyValue(true, for: characteristic)
                }
                

            }
        }
    }
    
    
    /*
     Invoked when you retrieve a specified characteristic’s value, 
     or when the peripheral device notifies your app that the characteristic’s value has changed.
     
     This method is invoked when your app calls the readValueForCharacteristic: method,
     or when the peripheral notifies your app that the value of the characteristic for 
     which notifications and indications are enabled has changed. 
     
     If successful, the error parameter is nil. 
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("ERROR ON UPDATING VALUE FOR CHARACTERISTIC: \(characteristic) - \(String(describing: error?.localizedDescription))")
            return
        }
        
        // extract the data from the characteristic's value property and display the value based on the characteristic type
        if characteristic.uuid == CBUUID(string: Device.SerialPortUUID) {
            if keepUpdatingRSSI && UIApplication.shared.applicationState == .background {
                Papaya?.readRSSI()

                if currRSSI > -62 && prevRSSI > -62 && backgroundSingleAuthenticate == false {
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    backgroundSingleAuthenticate = true
                    singleAuthenticate = false
                    if #available(iOS 10.0, *) {
                        // Create Notification Content
                        let notificationContent = UNMutableNotificationContent()
                        
                        // Configure Notification Content
                        notificationContent.title = "Papaya"
                        notificationContent.subtitle = "Login"
                        
                        
                        // Create Notification Request
                        let notificationRequest = UNNotificationRequest(identifier: "Papaya_Login", content: notificationContent, trigger: nil)
                        
                        // Add Request to User Notification Center
                        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                            if let error = error {
                                print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                            }
                        }
                    }
                } else if currRSSI <= -62 && prevRSSI <= -62 {
                    backgroundSingleAuthenticate = false
                }
            }
            }
        
    }
    
    func RSSIToDistance(rssiValue: Double) -> Double {
        let rssiAtOneMeter = -62.0 as Double
        return Double(pow(10, (rssiAtOneMeter - rssiValue) / 20))
    }


    func sendMessageToDevice(_ message: String) {
        if let data = message.data(using: String.Encoding.utf8) {
            guard isReady else { return }
            Papaya?.writeValue(data, for: serialCharacteristic!, type: writeType)
        }
    }
    
    func authenticationWithTouchID() {
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use Passcode"
        
        var authError: NSError?
        let reasonString = "To access the secure data"
        
        if localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            
            localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reasonString) { success, evaluateError in
                
                if success {
                    
                    let defaults = UserDefaults.standard
                    let token = defaults.string(forKey: "Credentials")
                    if (token == nil || token == "") {
                        self.sendMessageToDevice("<helloooo>")
                    } else {
                        self.sendMessageToDevice("<" + token! + ">")
                    }
                    
                } else {
                    //TODO: User did not authenticate successfully, look at error and take appropriate action
                    guard let error = evaluateError else {
                        return
                    }
                    
                    print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: error._code))
                    
                    //TODO: If you have choosen the 'Fallback authentication mechanism selected' (LAError.userFallback). Handle gracefully
                    
                }
            }
        } else {
            
            guard let error = authError else {
                return
            }
            //TODO: Show appropriate alert if biometry/TouchID/FaceID is lockout or not enrolled
            print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: error.code))
        }
    }
    
    func evaluatePolicyFailErrorMessageForLA(errorCode: Int) -> String {
        var message = ""
        if #available(iOS 11.0, macOS 10.13, *) {
            switch errorCode {
            case LAError.biometryNotAvailable.rawValue:
                message = "Authentication could not start because the device does not support biometric authentication."
                
            case LAError.biometryLockout.rawValue:
                message = "Authentication could not continue because the user has been locked out of biometric authentication, due to failing authentication too many times."
                
            case LAError.biometryNotEnrolled.rawValue:
                message = "Authentication could not start because the user has not enrolled in biometric authentication."
                
            default:
                message = "Did not find error code on LAError object"
            }
        } else {
            switch errorCode {
            case LAError.touchIDLockout.rawValue:
                message = "Too many failed attempts."
                
            case LAError.touchIDNotAvailable.rawValue:
                message = "TouchID is not available on the device"
                
            case LAError.touchIDNotEnrolled.rawValue:
                message = "TouchID is not enrolled on the device"
                
            default:
                message = "Did not find error code on LAError object"
            }
        }
        
        return message;
    }
    
    func evaluateAuthenticationPolicyMessageForLA(errorCode: Int) -> String {
        
        var message = ""
        
        switch errorCode {
            
        case LAError.authenticationFailed.rawValue:
            message = "The user failed to provide valid credentials"
            
        case LAError.appCancel.rawValue:
            message = "Authentication was cancelled by application"
            
        case LAError.invalidContext.rawValue:
            message = "The context is invalid"
            
        case LAError.notInteractive.rawValue:
            message = "Not interactive"
            
        case LAError.passcodeNotSet.rawValue:
            message = "Passcode is not set on the device"
            
        case LAError.systemCancel.rawValue:
            message = "Authentication was cancelled by the system"
            
        case LAError.userCancel.rawValue:
            message = "The user did cancel"
            
        case LAError.userFallback.rawValue:
            message = "The user chose to use the fallback"
            
        default:
            message = evaluatePolicyFailErrorMessageForLA(errorCode: errorCode)
        }
        
        return message
    }
}

@available(iOS 10.0, *)
extension HomeViewController: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert])
    }
    
}
