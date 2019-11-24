
#include <AESLib.h>
#define MAX_MESSAGE_SIZE 256
void setup() {
  Serial.begin(115200);

}

void loop() {
  uint8_t key[] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31};
uint8_t data[MAX_MESSAGE_SIZE+1] = "hello my name is karim and i like to play around";
aes256_enc_single(key, data);
Serial.print("encrypted:");
//Serial.println(data);
aes256_dec_single(key, data);
Serial.print("decrypted:");
for (int i=0; i<sizeof data; i++) {
   char s = data[i];
  Serial.println(s);
}
delay(3000);
}
