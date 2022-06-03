
#include "BluetoothSerial.h"

#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to and enable it
#endif

#include <HX711_ADC.h>
#if defined(ESP8266)|| defined(ESP32) || defined(AVR)
#include <EEPROM.h>
#endif

BluetoothSerial SerialBT;

const int HX711_dout = 18; //mcu > HX711 dout pin
const int HX711_sck = 19; //mcu > HX711 sck pin

//HX711 constructor:
HX711_ADC LoadCell(HX711_dout, HX711_sck);

//Variáveis para armazenamentos do handle das tasks
TaskHandle_t task1Handle = NULL;
TaskHandle_t task2Handle = NULL;
TaskHandle_t task3Handle = NULL;

//protótipos das Tasks
void vTask1(void *pvParameters);
void vTask2(void *pvParameters);
void vTask3(void *pvParameters);

const int id_eepromAdress = 200;
const int calVal_eepromAdress = 0;

char c;
String frase  = "";
  
QueueHandle_t xFilaPesos;

void setup() 
{
  Serial.begin(9600);
  SerialBT.begin("ESP32_CLASSIC_BT"); //Bluetooth device name

  

  xTaskCreatePinnedToCore(vTask1,"TASK1",configMINIMAL_STACK_SIZE+1024,NULL,2,&task1Handle,0);
  xTaskCreatePinnedToCore(vTask2,"TASK2",configMINIMAL_STACK_SIZE+2024,NULL,1,&task2Handle,0);
  xTaskCreatePinnedToCore(vTask3,"TASK3",configMINIMAL_STACK_SIZE+2024,NULL,1,&task3Handle,1);

  //inicializa a fila, troca de valores entre filas
  xFilaPesos= xQueueCreate(1,sizeof(double));
  
    LoadCell.begin();
    //LoadCell.setReverseOutput(); //uncomment to turn a negative output value to positive
    unsigned long stabilizingtime = 2000; // preciscion right after power-up can be improved by adding a few seconds of stabilizing time
    boolean _tare = true; //set this to false if you don't want tare to be performed in the next step
    LoadCell.start(stabilizingtime, _tare);
    if (LoadCell.getTareTimeoutFlag() || LoadCell.getSignalTimeoutFlag()) {
     Serial.println("Timeout, check MCU>HX711 wiring and pin designations");
    while (1);
    }
    else {
      LoadCell.setCalFactor(-21.38); // user set calibration value (float), initial value 1.0 may be used for this sketch
      Serial.println("Startup is complete");
    }
    while (!LoadCell.update());
    //calibrate(); //start calibration procedure
    //Tara();

}

void loop() {
 vTaskDelay(1000);

}


void vTask1(void *pvParameters){
 
  while(1)
  {
    if(SerialBT.available())
    {
       frase = "";
      while(SerialBT.available()) 
      {
        c = SerialBT.read();
        frase += c;
      }
    }
    
    
  if(frase == "tara"){
     
        frase = "";
        Tara();
  }
  else if(frase == "calibrar"){
     
      frase = "";
      Tara();
      calibrate();
  }
      
    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}
void vTask2(void *pvParameters){
 double pesoRecebido=0.0;
 String SerialData = "";
 
  while(1)
  {
    if(xQueueReceive(xFilaPesos,&pesoRecebido,pdMS_TO_TICKS(100)) == pdTRUE){
      //Serial.println("Peso Recebido:"+ String(pesoRecebido));
        SerialData = String(pesoRecebido,0);
        SerialBT.print(SerialData);
    }
    else{
      //Serial.println("TimeOut");
    }
    
    

    vTaskDelay(pdMS_TO_TICKS(500));
  }
}
void vTask3(void *pvParameters){
  

  double peso=0.0;
  
  
  while(1)
  {
      static boolean newDataReady = 0;
  
      // check for new data/start next conversion:
      if (LoadCell.update()) newDataReady = true;

      // get smoothed value from the dataset:
      if (newDataReady) 
      { 
        peso = LoadCell.getData();
 
        if(peso > -200 && peso < 100000)
          xQueueSend(xFilaPesos,&peso,pdMS_TO_TICKS(10));
        //Serial.print("Load_cell output val: ");
        //Serial.println(peso);
        newDataReady = 0;
      }
  vTaskDelay(pdMS_TO_TICKS(100));
  }
}


void Tara()
{
  boolean flag = true;
  boolean _resume = false;
  
  while (_resume == false) {
    
    LoadCell.update();
    if(flag){
       LoadCell.tareNoDelay();
       flag = false;
    }
     
    
    if (LoadCell.getTareStatus() == true) {
      Serial.println("Tare complete");
      _resume = true;
    }
  }
   
}


void calibrate() {
  Serial.println("***");
  Serial.println("Start calibration:");
  Serial.println("Place the load cell an a level stable surface.");
  Serial.println("Remove any load applied to the load cell.");
  Serial.println("Send 't' from serial monitor to set the tare offset.");
  bool flag = true;
  boolean _resume = false;
  //while (_resume == false) 
  //{
    //LoadCell.update();
   
     // while(SerialBT.available()) 
      //{
        //c = SerialBT.read();
        //frase += c;
      //}
      //if (frase == "tara"){
        //LoadCell.tareNoDelay();
        //frase = "";
      //}     
    //LoadCell.update();
    
    //if (LoadCell.getTareStatus() == true) {
    //  Serial.println("Tare complete");
    //  _resume = true;
    //}
    //delay(100);
  //}

  Serial.println("Now, place your known mass on the loadcell.");
  Serial.println("Then send the weight of this mass (i.e. 100.0) from serial monitor.");

  float known_mass = 0;
  _resume = false;
  frase = "";
  while (_resume == false) 
  {
    LoadCell.update();
      while(SerialBT.available()) 
      {
        c = SerialBT.read();
        frase += c;
      }   
       
      if (frase != "") {
        known_mass = frase.toFloat();
        Serial.print("Known mass is: ");
        Serial.println(known_mass);
        _resume = true;
      }
  delay(100);    
  }

  LoadCell.refreshDataSet(); //refresh the dataset to be sure that the known mass is measured correct
  float newCalibrationValue = LoadCell.getNewCalibration(known_mass); //get the new calibration value

  Serial.print("New calibration value has been set to: ");
  Serial.print(newCalibrationValue);
  Serial.println(", use this as calibration value (calFactor) in your project sketch.");
  Serial.print("Save this value to EEPROM adress ");
  Serial.print(calVal_eepromAdress);
        
//  EEPROM.begin(512);
//
//  EEPROM.put(calVal_eepromAdress, newCalibrationValue);
//
//  EEPROM.commit();
//
//  EEPROM.get(calVal_eepromAdress, newCalibrationValue);
//  Serial.print("Value ");
//  Serial.print(newCalibrationValue);
//  Serial.print(" saved to EEPROM address: ");
//  Serial.println(calVal_eepromAdress);
//     
//
//  Serial.println("End calibration");
//  Serial.println("***");
//  Serial.println("To re-calibrate, send 'r' from serial monitor.");
//  Serial.println("For manual edit of the calibration value, send 'c' from serial monitor.");
//  Serial.println("***");
 
}

void changeSavedCalFactor() {
  float oldCalibrationValue = LoadCell.getCalFactor();
  boolean _resume = false;
  Serial.println("***");
  Serial.print("Current value is: ");
  Serial.println(oldCalibrationValue);
  Serial.println("Now, send the new value from serial monitor, i.e. 696.0");
  float newCalibrationValue;
  while (_resume == false) {
    if (Serial.available() > 0) {
      newCalibrationValue = Serial.parseFloat();
      if (newCalibrationValue != 0) {
        Serial.print("New calibration value is: ");
        Serial.println(newCalibrationValue);
        LoadCell.setCalFactor(newCalibrationValue);
        _resume = true;
      }
    }
  }
  _resume = false;
  Serial.print("Save this value to EEPROM adress ");
  Serial.print(calVal_eepromAdress);
  Serial.println("? y/n");
  while (_resume == false) {
    if (Serial.available() > 0) {
      char inByte = Serial.read();
      if (inByte == 'y') {
#if defined(ESP8266)|| defined(ESP32)
        EEPROM.begin(512);
#endif
        EEPROM.put(calVal_eepromAdress, newCalibrationValue);
#if defined(ESP8266)|| defined(ESP32)
        EEPROM.commit();
#endif
        EEPROM.get(calVal_eepromAdress, newCalibrationValue);
        Serial.print("Value ");
        Serial.print(newCalibrationValue);
        Serial.print(" saved to EEPROM address: ");
        Serial.println(calVal_eepromAdress);
        _resume = true;
      }
      else if (inByte == 'n') {
        Serial.println("Value not saved to EEPROM");
        _resume = true;
      }
    }
  }
  Serial.println("End change calibration value");
  Serial.println("***");
}
