Smart Irrigator — Automated Irrigation System via Bluetooth

An automated irrigation system for residential gardens, controlled by an ESP32 microcontroller and operated through a mobile application via Bluetooth Low Energy (BLE). The system monitors soil moisture in real time and triggers irrigation automatically only when needed, promoting the rational use of water.

Undergraduate Thesis (Trabalho de Conclusão de Curso) — Electronic Engineering, Federal University of Technology – Paraná (UTFPR), Campo Mourão Campus, 2026.


Note: The source code comments are written in Portuguese (pt-BR).




About the Project

Traditional irrigation methods, based on manual activation or fixed-schedule timers, are inefficient: they water even when the soil is already moist, wasting water and harming plants through overwatering. This project proposes a low-cost solution that uses real soil moisture readings to decide when to irrigate, operating in a closed loop.

The system is divided into two main parts:


Firmware (ESP32): responsible for reading the sensors, controlling the valves, managing the schedule through a real-time clock (RTC), and handling BLE communication.
Mobile application (Flutter): interface that allows the user to register plants, configure irrigation parameters, and monitor the system state in real time.



How It Works

The irrigation of each plant is triggered when three conditions are simultaneously satisfied:


Time of day — irrigation occurs within a predefined time window (10 p.m. to 6 a.m.), the period of lowest evaporation.
Time interval — the time elapsed since the last watering must be greater than or equal to the interval registered for the plant.
Soil moisture — the sensor reading must indicate that the soil has reached the critical dryness level.


The system monitors all plants simultaneously, but irrigates them sequentially (one valve at a time), preventing current peaks that would compromise the stability of the power supply.


Technologies and Components

Hardware


ESP32 DevKit V1 (microcontroller with native BLE)
Resistive soil moisture sensors (HL-69)
12V DC solenoid valves, 1/2", normally closed (NC)
5V optocoupled relay module
DS3231 real-time clock (RTC) module (I2C communication)
LM2596 Buck converter (12V to 5V)
PCB manufactured on phenolite board (thermal transfer method)


Firmware


C++ on the Arduino IDE
Libraries: BLEDevice, RTClib, ArduinoJson, Wire
Non-blocking time control using millis()
Per-plant data structures using struct


Application


Flutter / Dart
State management with Provider (Singleton pattern)
BLE communication with flutter_blue_plus
JSON-based communication protocol



BLE Communication Protocol

Communication between the application and the ESP32 uses the GATT profile, with messages encapsulated in JSON format. The available actions are:

ActionDirectionDescriptionGET_PLANT_LISTApp -> ESP32Requests the list of registered plantsCREATE_PLANTApp -> ESP32Registers a new plant with its parametersDELETE_PLANTApp -> ESP32Removes a plant by nameCONFIGURE_RTCApp -> ESP32Synchronizes the clock with the phone's timestamp

Each response from the ESP32 includes the fields status (SUCCESS or ERROR), action, message, and payload.


Repository Structure

.
├── Irrigacao_final01/      # ESP32 firmware
│   └── Irrigacao_final01.ino
│
└── TCC_teste01/            # Flutter mobile application
    ├── lib/
    │   ├── models.dart
    │   ├── app_bluetooth_service.dart
    │   ├── plant_detail_page.dart
    │   └── register_plant_page.dart
    └── pubspec.yaml


How to Run

Firmware (ESP32)


Install the Arduino IDE and the ESP32 board package.
Install the libraries: RTClib, ArduinoJson.
Open the file Irrigacao_final01/Irrigacao_final01.ino.
Select the "ESP32 Dev Module" board and the correct port.
Compile and upload the firmware to the board.


Application (Flutter)


Install the Flutter SDK.
Inside the TCC_teste01/ folder, run flutter pub get to download the dependencies.
Connect an Android device or start an emulator.
Run flutter run.



Results


Measured dripper flow rate: 9.0 mL/s
Sensor calibration range: 0 to 4095 (ESP32 12-bit ADC)
Continuous operation for 24 hours with no leaks in the hydraulic connections
7 functional test scenarios validated, including automatic activation by soil moisture, immediate verification after registration, and recovery from RTC failure



Future Work


Wi-Fi connectivity for remote monitoring and control over the internet
Replacement with capacitive sensors (greater durability)
Integration of a rain sensor as a fourth control condition
Emergency threshold for irrigation outside the time window in case of critical dryness
Integrated PCB with discrete components, eliminating the ready-made modules
Quantitative comparative test of water savings (sensor vs. fixed timer)



Author

Luiz Gustavo Vieira Sampaio
Electronic Engineering — UTFPR Campo Mourão

Advisor: Prof. Leandro Castilho Brolin
Co-advisor: Prof. Lucas Ricken Garcia


License

This project is licensed under the MIT License — see the LICENSE file for details.
