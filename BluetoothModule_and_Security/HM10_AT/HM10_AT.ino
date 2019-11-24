#include <SoftwareSerial.h>
SoftwareSerial BTSerial(1,0); //RX|TX
 
void setup(){
  Serial.begin(9600);
  BTSerial.begin(9600); // default baud rate
  while(!Serial); //if it is an Arduino Micro
  Serial.println("AT commands: ");
}
 
void loop(){
  //read from the HM-10 and print in the Serial
  if(BTSerial.available())
    Serial.write(BTSerial.read());
    
  //read from the Serial and print to the HM-10
  if(Serial.available())
    BTSerial.write(Serial.read());
}
