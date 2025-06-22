#include <Arduino.h>
#include "Arduino_GFX_Library.h"
#include "pin_config.h"
#include <Wire.h>
#include "HWCDC.h"
#include "MAX30105.h"

#include "heartRate.h"

MAX30105 particleSensor;

const byte RATE_SIZE = 4; //Increase this for more averaging. 4 is good.
byte rates[RATE_SIZE]; //Array of heart rates
byte rateSpot = 0;
long lastBeat = 0; //Time at which the last beat occurred

float beatsPerMinute;
int beatAvg;

Arduino_DataBus *bus = new Arduino_ESP32SPI(LCD_DC, LCD_CS, LCD_SCK, LCD_MOSI);

Arduino_GFX *gfx = new Arduino_ST7789(bus, LCD_RST /* RST */,
                                      0 /* rotation */, true /* IPS */, LCD_WIDTH, LCD_HEIGHT, 0, 20, 0, 0);

void setup(void) {
  USBSerial.begin(115200);
  // USBSerial.setDebugOutput(true);
  // while(!USBSerial);
  USBSerial.println("Arduino_GFX Hello World example");
  USBSerial.println("Initializing...");

  // Initialize sensor
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) //Use default I2C port, 400kHz speed
  {
    USBSerial.println("MAX30102 was not found. Please check wiring/power. ");
    while (1);
  }
  USBSerial.println("Place your index finger on the sensor with steady pressure.");
 particleSensor.setup(); //Configure sensor with default settings
  particleSensor.setPulseAmplitudeRed(0x0A); //Turn Red LED to low to indicate sensor is running
  particleSensor.setPulseAmplitudeGreen(0); //Turn off Green LED 
  // Init Display
  if (!gfx->begin()) {
    USBSerial.println("gfx->begin() failed!");
  }
  gfx->fillScreen(BLACK);

  pinMode(LCD_BL, OUTPUT);
  digitalWrite(LCD_BL, HIGH);

  gfx->setCursor(10, 10);
  gfx->setTextColor(RED);
  gfx->println("Hello World!");

  delay(5000);  // 5 seconds
}

void loop() {
   long irValue = particleSensor.getIR();

   USBSerial.print("IR Value: ");
   USBSerial.println(irValue);

  if (checkForBeat(irValue) == true)
  {
    //We sensed a beat!
    long delta = millis() - lastBeat;
    lastBeat = millis();

    beatsPerMinute = 60 / (delta / 1000.0);

    if (beatsPerMinute < 255 && beatsPerMinute > 20)
    {
      rates[rateSpot++] = (byte)beatsPerMinute; //Store this reading in the array
      rateSpot %= RATE_SIZE; //Wrap variable

      //Take average of readings
      beatAvg = 0;
      for (byte x = 0 ; x < RATE_SIZE ; x++)
        beatAvg += rates[x];
      beatAvg /= RATE_SIZE;
    }
  }

  USBSerial.print("IR=");
  USBSerial.print(irValue);
  USBSerial.print(", BPM=");
  USBSerial.print(beatsPerMinute);
  USBSerial.print(", Avg BPM=");
  USBSerial.print(beatAvg);
  if (irValue < 50000)
    USBSerial.print(" No finger?");

  USBSerial.println();
  gfx->setCursor(random(gfx->width()), random(gfx->height()));
  gfx->setTextColor(random(0xffff), random(0xffff));
  gfx->setTextSize(random(6) /* x scale */, random(6) /* y scale */, random(2) /* pixel_margin */);
  gfx->println("Hello World!");

  delay(1000);  // 1 second
}
