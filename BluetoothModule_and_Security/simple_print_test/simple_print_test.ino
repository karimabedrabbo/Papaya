void setup() {
 Serial.begin(9600);
}

void loop() {
 Serial.print("Millis: ");
 Serial.println(millis());
 delay(1000);
}
