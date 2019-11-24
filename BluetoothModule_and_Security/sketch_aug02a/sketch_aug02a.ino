#define mySerial Serial1

void setup() {
     Serial.begin(9600);
     mySerial.begin(9600);


      Serial.println("BLE CC41A Bluetooth");
      Serial.println("----------------------------------");
      Serial.println("");
      Serial.println("Trying to connect to Slave Bluetooth");
      delay(1000);
      mySerial.println("AT"); // just a check
      delay(2000);
      mySerial.println("AT+ROLE1"); // st up as Master
      delay(2000);
      mySerial.println("AT+IMME1"); // look for nearby Slave
      delay(5000);
      mySerial.println("AT+RESET"); // connect to it
      delay(10000);
      mySerial.println("AT+DISC?"); // find nearest beacons
}

void loop() {
  // put your main code here, to run repeatedly:
  if (mySerial.available()) {
      delay(10);
      Serial.write(mySerial.read());
    }
    if (Serial.available()) {
      mySerial.write(Serial.read());
    }

    
}
