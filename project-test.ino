//Libraries
#include <Adafruit_DHT.h>
#include <JsonParserGeneratorRK.h>

//Defining Pins
#define DHTPIN D7
#define DHTTYPE 11

DHT dht(DHTPIN, DHTTYPE);

//Our variables that will be used to store data in
float temperature;
float maxTemperature;
float humidity;
float maxHumidity;

//The payload function
//This will build the JSON object which will then be published to the console
void postEvent(float _temperature, float _humidity, float _maxTemp, float _maxHum){
    JsonWriterStatic<256> jw;
    {
        JsonWriterAutoObject obj(&jw);
        jw.insertKeyValue("temperature", _temperature);
        jw.insertKeyValue("humidity", _humidity);
        jw.insertKeyValue("maxTemperature", _maxTemp);
        jw.insertKeyValue("maxHumidity", _maxHum);
    }
    Particle.publish("dht11", jw.getBuffer(), PRIVATE);
}

int led = D7;

//DHT begin, Setting up the device.
void setup() {

    Serial.begin(9600);
    Serial.println("DHT TESTER");
    Particle.publish("state", "DHT test start");
    
    dht.begin();
    pinMode(DHTPIN, INPUT);
    Serial.begin();
    Serial.println("Initializing...");

}
//Getting the data
//Posting the data as a payload
//Repeat every 2 Seconds
void loop() {
    Particle.publish("Powering", "The device Has been turned on.");
    while (1<2){
        temperature = dht.getTempCelcius();
        humidity = dht.getHumidity();
        
        //DHT SENSOR is known to have issues on GEN 3 Particle Devices
        //Perform a quick check to ensure the data captured isn't NAN
        if (isnan(temperature) || isnan(humidity)|| humidity > 100 || humidity < 0){
            Particle.publish("DHT Sensor Error!");
        }
        
        //Else if the data we captured is fine then we prepare to post the event
        else {
            //Keep Track of Max Temperature reading
            if(temperature > maxTemperature){
                maxTemperature = temperature;
            }
            //Keep track of Maximum Humidity reading
            if(humidity > maxHumidity){
                maxHumidity = humidity;
            }
            postEvent(temperature, humidity, maxTemperature, maxHumidity);
        }
        //postEvent(lat, lng, temperature, humidity);
        //Particle.publish("Coords", coords, PRIVATE);
        delay(2000);
    }
}

