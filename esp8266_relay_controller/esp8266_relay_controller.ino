/*
 * ESP8266 Relay Controller with WiFiManager and OLED display
 * For Smart Home project
 * Supports 4 relays with custom naming
 */

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <WiFiManager.h>
#include <Wire.h>
// Заменяем библиотеки для дисплея
#include <U8g2lib.h>
#include <ESP8266mDNS.h>
#include <ArduinoJson.h>
#include <EEPROM.h>

// Определение пинов для реле - исправлены для избежания конфликтов с I2C (D1/D2)
// D1 (GPIO5) и D2 (GPIO4) используются для I2C (SDA/SCL) для дисплея
#define RELAY_1_PIN D5  // GPIO14
#define RELAY_2_PIN D6  // GPIO12
#define RELAY_3_PIN D7  // GPIO13
#define RELAY_4_PIN D8  // GPIO15

#define RESET_BUTTON_PIN D3 // Пин для кнопки сброса настроек

// Количество реле
#define NUM_RELAYS 4

// Настройка OLED дисплея
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

// Создаем объект дисплея для U8g2 (обновлено для поддержки дисплея 1,3 дюйма)
// Для дисплеев 1,3 дюйма обычно используется контроллер SH1106
U8G2_SH1106_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, D1, D2, U8X8_PIN_NONE);

// Если выше не работает, попробуйте этот вариант с аппаратным I2C
// U8G2_SH1106_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE, U8X8_PIN_NONE);

// Создание сервера
ESP8266WebServer server(80);

// Состояние реле
bool relayStates[NUM_RELAYS] = {false, false, false, false};

// Имена реле (по умолчанию)
String relayNames[NUM_RELAYS] = {"Реле 1", "Реле 2", "Реле 3", "Реле 4"};

// Имя устройства для mDNS и AP
const char* deviceName = "SmartRelay";

// Адреса в EEPROM для хранения имен реле
const int EEPROM_SIZE = 512;
const int NAME_MAX_LENGTH = 30;
const int RELAY_NAMES_START_ADDRESS = 0;
const int RELAY_STATES_START_ADDRESS = RELAY_NAMES_START_ADDRESS + (NAME_MAX_LENGTH * NUM_RELAYS);

// Пины реле, упорядоченные для удобства
const int relayPins[NUM_RELAYS] = {RELAY_1_PIN, RELAY_2_PIN, RELAY_3_PIN, RELAY_4_PIN};

// Переменные для работы с кнопкой сброса
bool resetButtonPressed = false;
unsigned long resetButtonPressTime = 0;
const unsigned long resetButtonLongPressTime = 5000; // 5 секунд для сброса

// Переменные для переключения страниц на дисплее
const unsigned long DISPLAY_PAGE_INTERVAL = 5000; // Интервал переключения страниц (5 секунд)
unsigned long lastDisplayPageChange = 0;
byte currentDisplayPage = 0; // 0 - информация о сети, 1 - состояние реле
const byte NUM_DISPLAY_PAGES = 3; // Количество страниц для отображения

// Переменные для спящего режима дисплея
const unsigned long DISPLAY_SLEEP_TIMEOUT = 300000; // Время до выключения дисплея (5 минут)
unsigned long lastActivityTime = 0;  // Время последней активности
bool displaySleepMode = false;       // Флаг спящего режима дисплея
bool inConfigurationMode = false;    // Флаг режима настройки WiFi (точка доступа)

// Добавляем структуры для работы со сценариями
struct ScenarioAction {
  int relayId;
  bool turnOn;
  int delayMs;
};

// Добавляем переменные для работы со сценариями
bool scenarioRunning = false;
unsigned long nextActionTime = 0;
int currentActionIndex = 0;
ScenarioAction pendingActions[10]; // Максимум 10 действий в сценарии
int pendingActionsCount = 0;

void setup() {
  Serial.begin(115200);
  
  // Инициализация EEPROM
  EEPROM.begin(EEPROM_SIZE);
  
  // Инициализация имен реле по умолчанию на русском
  relayNames[0] = "Реле 1"; // Исправлено с "Relay 1" на "Реле 1"
  relayNames[1] = "Реле 2"; // Исправлено с "Relay 2" на "Реле 2"
  relayNames[2] = "Реле 3"; // Исправлено с "Relay 3" на "Реле 3" 
  relayNames[3] = "Реле 4"; // Исправлено с "Relay 4" на "Реле 4"
  
  // Загрузка имен реле из EEPROM (перезапишет дефолтные значения, если были сохранены)
  loadRelayNames();
  
  // Загрузка состояний реле из EEPROM
  loadRelayStates();
  
  // Явная инициализация I2C для ESP8266
  Wire.begin(D2, D1); // SDA на D2, SCL на D1
  
  // Настройка пинов для реле
  for (int i = 0; i < NUM_RELAYS; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], relayStates[i] ? HIGH : LOW);
  }
  
  pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);
  
  // Инициализация дисплея с поддержкой кириллицы
  u8g2.begin();
  u8g2.enableUTF8Print(); // Включаем поддержку UTF-8 (для кириллицы)
  u8g2.setFont(u8g2_font_6x13_t_cyrillic); // Шрифт с поддержкой кириллицы
  u8g2.setFontRefHeightExtendedText();
  u8g2.setDrawColor(1);
  u8g2.setFontPosTop();
  u8g2.setFontDirection(0);
  
  // Показываем стартовое сообщение
  u8g2.clearBuffer();
  u8g2.setCursor(0, 0);
  u8g2.print(F("Запуск..."));
  u8g2.sendBuffer();
  
  // Настройка WiFiManager
  WiFiManager wifiManager;
  
  // Текст для точки доступа
  u8g2.clearBuffer();
  u8g2.setCursor(0, 0);
  u8g2.print(F("Подключитесь к WiFi:"));
  u8g2.setCursor(0, 12);
  u8g2.print(deviceName);
  u8g2.setCursor(0, 24);
  u8g2.print(F("для настройки сети"));
  u8g2.sendBuffer();
  
  // Устанавливаем флаг режима конфигурации WiFi
  inConfigurationMode = true;
  
  // Попытка подключения к WiFi или создание точки доступа
  if (!wifiManager.autoConnect(deviceName)) {
    Serial.println("Failed to connect and hit timeout");
    delay(3000);
    ESP.restart();
  }
  
  // Успешное подключение к WiFi - выключаем режим конфигурации
  inConfigurationMode = false;
  
  // Вывод информации о подключении
  displayNetworkInfo();
  lastDisplayPageChange = millis(); // Инициализация времени смены страницы
  
  // Настройка mDNS
  if (MDNS.begin(deviceName)) {
    Serial.println("mDNS responder started");
  }
  
  // Настройка маршрутов сервера
  server.on("/", HTTP_GET, handleRoot);
  server.on("/toggle", HTTP_GET, handleToggleRelay);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/set-name", HTTP_POST, handleSetRelayName);
  server.on("/ping", HTTP_GET, handlePing); // Добавляем простой эндпоинт для проверки соединения
  server.on("/run-scenario", HTTP_POST, handleRunScenario); // Добавляем эндпоинт для запуска сценария

  // Разрешаем CORS для всех запросов
  server.enableCORS(true);

  // Запуск сервера
  server.begin();
  Serial.println("HTTP server started");
  
  // Инициализация времени активности
  lastActivityTime = millis();
}

void loop() {
  // Обработка HTTP-запросов
  server.handleClient();
  
  // Проверка и выполнение действий сценария
  processScenarioActions();
  
  // Обработка кнопки сброса
  handleResetButton();
  
  // Обновление состояния mDNS
  MDNS.update();
  
  // Обновление дисплея и проверка спящего режима
  updateDisplayWithSleep();
}

// Функция для фиксации активности и сброса таймера сна
void recordActivity() {
  lastActivityTime = millis();
  
  // Если дисплей был в спящем режиме - пробуждаем его
  if (displaySleepMode) {
    wakeDisplay();
  }
}

// Включение дисплея
void wakeDisplay() {
  if (displaySleepMode) {
    displaySleepMode = false;
    u8g2.setPowerSave(0); // Включаем дисплей
    
    // Показываем текущую страницу
    switch (currentDisplayPage) {
      case 0:
        displayNetworkInfo();
        break;
      case 1:
        displayRelayStatus();
        break;
      case 2:
        drawPage3();
        break;
    }
    
    Serial.println("Дисплей активирован");
  }
}

// Выключение дисплея
void sleepDisplay() {
  if (!displaySleepMode) {
    displaySleepMode = true;
    u8g2.setPowerSave(1); // Отключаем дисплей для экономии энергии
    Serial.println("Дисплей перешел в спящий режим");
  }
}

// Обновленная функция для обновления дисплея с учетом спящего режима
void updateDisplayWithSleep() {
  // Проверка таймаута неактивности для перехода в спящий режим
  // Не уходим в спящий режим, если в режиме конфигурации WiFi
  if (!inConfigurationMode && !displaySleepMode && (millis() - lastActivityTime > DISPLAY_SLEEP_TIMEOUT)) {
    sleepDisplay();
    return;
  }
  
  // Если дисплей в спящем режиме, не обновляем его
  if (displaySleepMode) {
    return;
  }
  
  // Проверяем, не нажата ли кнопка сброса
  if (!resetButtonPressed) {
    // Проверяем, прошло ли достаточно времени для смены страницы
    if (millis() - lastDisplayPageChange >= DISPLAY_PAGE_INTERVAL) {
      // Определяем количество доступных страниц в зависимости от наличия активного сценария
      byte availablePages = (scenarioRunning && pendingActionsCount > 0) ? 3 : 2;
      
      // Переключаем на следующую страницу
      currentDisplayPage = (currentDisplayPage + 1) % availablePages;
      lastDisplayPageChange = millis();
      
      // Отображаем соответствующую страницу
      switch (currentDisplayPage) {
        case 0:
          displayNetworkInfo();
          break;
        case 1:
          displayRelayStatus();
          break;
        case 2:
          if (scenarioRunning && pendingActionsCount > 0) {
            drawPage3();
          } else {
            currentDisplayPage = 0;
            displayNetworkInfo();
          }
          break;
      }
    }
  }
}

// Добавим также возможность программно включать/выключать режим конфигурации
void setConfigurationMode(bool enabled) {
  inConfigurationMode = enabled;
  
  // Если включаем режим конфигурации, убедимся что дисплей включен
  if (enabled && displaySleepMode) {
    wakeDisplay();
  }
}

void handleRoot() {
  recordActivity(); // Регистрируем активность
  // Отправляем HTML-страницу с элементами управления реле
  String html = "<!DOCTYPE html><html><head>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<meta charset='UTF-8'>";
  html += "<style>";
  html += "body{font-family:Arial,sans-serif;text-align:center;margin:0;padding:0;background-color:#f5f7fa;}";
  html += ".container{max-width:800px;margin:0 auto;padding:20px;}";
  html += ".header{background-color:#2c3e50;color:white;padding:20px;border-radius:10px 10px 0 0;margin-bottom:20px;}";
  html += ".relay-card{background-color:white;border-radius:15px;box-shadow:0 4px 6px rgba(0,0,0,0.1);padding:20px;margin-bottom:20px;position:relative;overflow:hidden;}";
  html += ".relay-status{font-weight:bold;}";
  html += ".on{color:#1abc9c;}";
  html += ".off{color:#7f8c8d;}";
  html += ".status-indicator{position:absolute;left:0;top:0;bottom:0;width:8px;}";
  html += ".btn{border:none;padding:12px 24px;font-size:16px;border-radius:10px;cursor:pointer;margin:10px;color:white;}";
  html += ".btn-on{background-color:#1abc9c;}";
  html += ".btn-off{background-color:#e74c3c;}";
  html += ".name-form{display:flex;margin-top:10px;align-items:center;justify-content:center;}";
  html += ".name-input{padding:10px;border:1px solid #ddd;border-radius:10px;margin-right:10px;flex:1;}";
  html += ".btn-save{background-color:#3498db;padding:10px 15px;font-size:14px;}";
  html += ".scenario-info{background-color:#f8f9fa;padding:10px;border-radius:10px;margin-top:20px;}";
  html += "</style>";
  html += "</head><body>";
  html += "<div class='container'>";
  html += "<div class='header'><h1>Smart Relay Control</h1></div>";
  
  for (int i = 0; i < NUM_RELAYS; i++) {
    html += "<div class='relay-card'>";
    html += "<div class='status-indicator' style='background-color:" + String(relayStates[i] ? "#1abc9c" : "#7f8c8d") + ";'></div>";
    html += "<h2>" + relayNames[i] + "</h2>";
    html += "<p>Status: <span class='relay-status " + String(relayStates[i] ? "on" : "off") + "'>" + String(relayStates[i] ? "ON" : "OFF") + "</span></p>";
    html += "<button class='btn " + String(relayStates[i] ? "btn-off" : "btn-on") + "' onclick=\"location.href='/toggle?relay=" + String(i) + "'\">";
    html += String(relayStates[i] ? "Turn OFF" : "Turn ON") + "</button>";
    
    html += "<form class='name-form' action='/set-name' method='POST'>";
    html += "<input type='hidden' name='relay' value='" + String(i) + "'>";
    html += "<input class='name-input' type='text' name='name' placeholder='New name for relay' value='" + relayNames[i] + "'>";
    html += "<button type='submit' class='btn btn-save'>Save</button>";
    
    html += "</form>";
    
    html += "</div>";
  }
  
  // Добавляем информацию о сценариях
  html += "<div class='scenario-info'>";
  html += "<h2>Поддержка сценариев</h2>";
  html += "<p>Это устройство поддерживает выполнение сценариев автоматизации.</p>";
  
  if (scenarioRunning) {
    html += "<p>Статус: <span style='color:#1abc9c;font-weight:bold;'>Выполняется сценарий</span></p>";
    html += "<p>Выполнено действий: " + String(currentActionIndex) + " из " + String(pendingActionsCount) + "</p>";
  } else {
    html += "<p>Статус: <span style='color:#7f8c8d;'>Ожидание команд</span></p>";
  }
  
  html += "<p>API для запуска сценариев: POST /run-scenario с JSON массивом действий</p>";
  html += "</div>";
  
  html += "</div></body></html>";
  server.send(200, "text/html; charset=utf-8", html);
}

void handleToggleRelay() {
  recordActivity(); // Регистрируем активность
  
  // Проверяем, указан ли номер реле
  if (!server.hasArg("relay")) {
    server.send(400, "text/plain", "Missing relay parameter");
    return;
  }
  
  int relayIndex = server.arg("relay").toInt();
  
  // Проверяем, что индекс в допустимом диапазоне
  if (relayIndex < 0 || relayIndex >= NUM_RELAYS) {
    server.send(400, "text/plain", "Invalid relay index");
    return;
  }
  
  // Изменяем состояние реле
  relayStates[relayIndex] = !relayStates[relayIndex];
  digitalWrite(relayPins[relayIndex], relayStates[relayIndex] ? HIGH : LOW);
  
  // Сохраняем состояние в EEPROM
  saveRelayStates();
  
  // Обновляем дисплей, но не переключаем страницу
  if (currentDisplayPage == 1) {
    // Если сейчас отображается страница состояния реле, обновляем ее
    displayRelayStatus();
  }
  
  // Добавляем CORS заголовки перед отправкой ответа
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");

  // Перенаправляем обратно на главную страницу
  server.sendHeader("Location", "/", true);
  server.send(302, "text/plain", "");
}

void handleSetRelayName() {
  recordActivity(); // Регистрируем активность
  
  // Проверяем, указаны ли необходимые параметры
  if (!server.hasArg("relay") || !server.hasArg("name")) {
    server.send(400, "text/plain", "Missing relay or name parameter");
    return;
  }
  
  int relayIndex = server.arg("relay").toInt();
  String newName = server.arg("name");
  
  // Проверяем, что индекс в допустимом диапазоне
  if (relayIndex < 0 || relayIndex >= NUM_RELAYS) {
    server.send(400, "text/plain", "Invalid relay index");
    return;
  }
  
  // Ограничиваем длину имени
  if (newName.length() > NAME_MAX_LENGTH - 1) {
    newName = newName.substring(0, NAME_MAX_LENGTH - 1);
  }
  
  // Устанавливаем новое имя
  relayNames[relayIndex] = newName;
  
  // Сохраняем имена в EEPROM
  saveRelayNames();
  
  // Добавляем CORS заголовки перед отправкой ответа
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");

  // Перенаправляем обратно на главную страницу
  server.sendHeader("Location", "/", true);
  server.send(302, "text/plain", "");
}

// Модификация метода handleStatus для корректной обработки имен
void handleStatus() {
  recordActivity(); // Регистрируем активность
  
  // Отправляем JSON с текущим состоянием реле
  DynamicJsonDocument doc(1024);
  
  doc["ip"] = WiFi.localIP().toString();
  doc["rssi"] = WiFi.RSSI();
  
  // Добавляем массив с информацией о реле
  JsonArray relays = doc.createNestedArray("relays");
  for (int i = 0; i < NUM_RELAYS; i++) {
    JsonObject relay = relays.createNestedObject();
    relay["id"] = i;
    
    // Экранируем только контрольные символы, оставляя кириллицу
    String safeName = relayNames[i];
    safeName.replace("\r", "");
    safeName.replace("\n", "");
    safeName.replace("\t", "");
    
    // Проверяем имя на валидность и добавляем более строгую проверку
    if (safeName.length() == 0 || safeName == "_" || safeName == "undefined") {
      safeName = "Реле " + String(i+1); // Используем русский вариант имени
    }
    
    relay["name"] = safeName;
    relay["state"] = relayStates[i] ? "on" : "off";
  }
  
  // Добавляем информацию о сценариях
  doc["scenarios"] = JsonObject();
  doc["scenarios"]["supported"] = true;
  doc["scenarios"]["running"] = scenarioRunning;
  doc["scenarios"]["progress"] = scenarioRunning ? 
                              (currentActionIndex * 100) / pendingActionsCount : 0;
  
  String jsonResponse;
  serializeJson(doc, jsonResponse);
  
  // Добавляем CORS заголовки и явно указываем кодировку UTF-8
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  server.sendHeader("Content-Type", "application/json; charset=utf-8");
  server.send(200, "application/json; charset=utf-8", jsonResponse);
  
  Serial.println("Status request - sent response: " + jsonResponse);
}

void handleResetButton() {
  // Проверка состояния кнопки сброса
  if (digitalRead(RESET_BUTTON_PIN) == LOW) { // Кнопка нажата
    recordActivity(); // Регистрируем активность при нажатии кнопки
    
    if (!resetButtonPressed) {
      resetButtonPressed = true;
      resetButtonPressTime = millis();
      
      // Отображаем на экране информацию о начале сброса
      u8g2.clearBuffer();
      u8g2.setCursor(0, 0);
      u8g2.print(F("Удерживайте кнопку"));
      u8g2.setCursor(0, 12);
      u8g2.print(F("5 секунд для сброса"));
      u8g2.sendBuffer();
    } else {
      // Проверяем, нажата ли кнопка достаточно долго для сброса
      if (millis() - resetButtonPressTime >= resetButtonLongPressTime) {
        // Отображаем информацию о сбросе
        u8g2.clearBuffer();
        u8g2.setCursor(0, 0);
        u8g2.print(F("Сброс настроек"));
        u8g2.setCursor(0, 12);
        u8g2.print(F("Пожалуйста, ждите..."));
        u8g2.sendBuffer();
        
        // Сбрасываем настройки WiFi и перезагружаем устройство
        Serial.println("Resetting WiFi settings and rebooting");
        WiFiManager wifiManager;
        wifiManager.resetSettings();
        delay(1000);
        ESP.restart();
      }
    }
  } else {
    // Кнопка отпущена до выполнения сброса
    if (resetButtonPressed) {
      resetButtonPressed = false;
      
      // При отпускании кнопки возвращаемся к текущей странице
      switch (currentDisplayPage) {
        case 0:
          displayNetworkInfo();
          break;
        case 1:
          displayRelayStatus();
          break;
        case 2:
          drawPage3();
          break;
      }
      
      // Сбрасываем таймер смены страницы
      lastDisplayPageChange = millis();
    }
  }
}

void displayNetworkInfo() {
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_6x13_t_cyrillic);
  
  u8g2.setCursor(0, 0);
  u8g2.print(F("Сеть: "));
  u8g2.print(WiFi.SSID());
  
  u8g2.setCursor(0, 14);
  u8g2.print(F("IP: "));
  u8g2.print(WiFi.localIP().toString());
  
  u8g2.setCursor(0, 28);
  u8g2.print(F("Сигнал: "));
  u8g2.print(WiFi.RSSI());
  u8g2.print(F(" дБм"));
  
  u8g2.setCursor(0, 42);
  u8g2.print(F("Имя: "));
  u8g2.print(deviceName);
  
  
  
  u8g2.sendBuffer();
}

void displayRelayStatus() {
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_6x13_t_cyrillic);
  
  u8g2.setCursor(0, 0);
  u8g2.print(F("== Статус реле =="));
  
  for (int i = 0; i < NUM_RELAYS; i++) {
    u8g2.setCursor(0, 14 + i * 12);
    u8g2.print(i+1);
    u8g2.print(F(": "));
    
    // Показываем сначала имя реле (ограниченное по длине)
    String displayName = relayNames[i];
    if (displayName.length() > 20) {
      displayName = displayName.substring(0, 17) + "..";
    }
    u8g2.print(displayName);
    
    // Отступ для выравнивания статуса
    int statusX = 90;
    u8g2.setCursor(statusX, 14 + i * 12);
    u8g2.print(relayStates[i] ? F("ВКЛ") : F("ВЫКЛ"));
  }
  
  u8g2.sendBuffer();
}

void drawPage3() {
  // Если сценарий выполняется, показываем его статус
  if (scenarioRunning && pendingActionsCount > 0) {
    // Чистим буфер
    u8g2.clearBuffer();
    
    // Заголовок страницы
    u8g2.setFont(u8g2_font_7x13_tr);
    u8g2.drawStr(0, 10, "Статус сценария");
    
    u8g2.setCursor(0, 30);
    u8g2.print(F("Выполнение действий:"));
    u8g2.setCursor(0, 45);
    u8g2.print(F("Действие "));
    u8g2.print(currentActionIndex + 1);
    u8g2.print(F(" из "));
    u8g2.print(pendingActionsCount);
    
    // Отправляем буфер на дисплей
    u8g2.sendBuffer();
  }
}

int countActiveRelays() {
  int count = 0;
  for (int i = 0; i < NUM_RELAYS; i++) {
    if (relayStates[i]) {
      count++;
    }
  }
  return count;
}

// Функции для сохранения/загрузки данных из EEPROM

void saveRelayNames() {
  int address = RELAY_NAMES_START_ADDRESS;
  for (int i = 0; i < NUM_RELAYS; i++) {
    writeStringToEEPROM(address, relayNames[i]);
    address += NAME_MAX_LENGTH;
  }
  EEPROM.commit();
}

void loadRelayNames() {
  int address = RELAY_NAMES_START_ADDRESS;
  for (int i = 0; i < NUM_RELAYS; i++) {
    String name = readStringFromEEPROM(address);
    // Проверяем, что строка не пустая и не содержит мусор
    if (name.length() > 0 && name.length() < NAME_MAX_LENGTH) {
      relayNames[i] = name;
    }
    address += NAME_MAX_LENGTH;
  }
}

void saveRelayStates() {
  for (int i = 0; i < NUM_RELAYS; i++) {
    EEPROM.write(RELAY_STATES_START_ADDRESS + i, relayStates[i] ? 1 : 0);
  }
  EEPROM.commit();
}

void loadRelayStates() {
  for (int i = 0; i < NUM_RELAYS; i++) {
    relayStates[i] = (EEPROM.read(RELAY_STATES_START_ADDRESS + i) == 1);
  }
}

void writeStringToEEPROM(int address, String data) {
  // Ограничиваем длину строки
  int length = min((int)data.length(), NAME_MAX_LENGTH - 1);
  
  // Записываем длину строки
  EEPROM.write(address, length);
  
  // Записываем символы строки
  for (int i = 0; i < length; i++) {
    EEPROM.write(address + 1 + i, data[i]);
  }
  
  // Записываем нулевой символ
  EEPROM.write(address + 1 + length, 0);
}

// Улучшенное чтение строки из EEPROM с улучшенной защитой от ошибок
String readStringFromEEPROM(int address) {
  // Считываем длину строки
  int length = EEPROM.read(address);
  
  // Проверяем корректность длины более строго
  if (length > NAME_MAX_LENGTH - 1 || length <= 0) { // Проверка, что длина > 0
    // Возвращаем имя по умолчанию
    int relayIndex = (address - RELAY_NAMES_START_ADDRESS) / NAME_MAX_LENGTH;
    if (relayIndex >= 0 && relayIndex < NUM_RELAYS) {
      return "Реле " + String(relayIndex + 1);
    }
    return ""; // Если что-то пошло совсем не так
  }
  
  // Считываем символы строки
  uint8_t data[NAME_MAX_LENGTH]; // Используем uint8_t вместо char для поддержки UTF-8
  bool hasInvalidChars = false;
  int validChars = 0; // Счетчик валидных символов
  
  for (int i = 0; i < length; i++) {
    uint8_t c = EEPROM.read(address + 1 + i);
    // Проверяем только на невалидные контрольные символы
    if (c < 32 && c != 0) { // Разрешаем все печатные символы и 0
      hasInvalidChars = true;
      data[i] = '_'; // Заменяем невалидные символы
    } else {
      data[i] = c;
      if (c > 32) validChars++; // Увеличиваем счетчик непробельных символов
    }
  }
  data[length] = '\0';
  
  String result = String((char*)data);
  
  // Если нашли невалидные символы или имя состоит только из пробелов/подчеркиваний, 
  // используем имя по умолчанию
  if (hasInvalidChars || validChars == 0 || result == "_") {
    int relayIndex = (address - RELAY_NAMES_START_ADDRESS) / NAME_MAX_LENGTH;
    if (relayIndex >= 0 && relayIndex < NUM_RELAYS) {
      result = "Реле " + String(relayIndex + 1);
      
      // Перезаписываем в EEPROM корректное имя
      writeStringToEEPROM(address, result);
      EEPROM.commit();
    }
  }
  
  return result;
}

// Обновленный метод ping для быстрого отклика
void handlePing() {
  recordActivity(); // Регистрируем активность
  Serial.println("Ping request received");
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  server.sendHeader("Content-Type", "text/plain; charset=utf-8");
  server.send(200, "text/plain; charset=utf-8", "OK");
}

// Обработка действий сценария
void processScenarioActions() {
  if (scenarioRunning && pendingActionsCount > 0) {
    if (millis() >= nextActionTime && currentActionIndex < pendingActionsCount) {
      // Выполняем текущее действие
      ScenarioAction action = pendingActions[currentActionIndex];
      
      // Проверяем, что индекс реле в допустимом диапазоне
      if (action.relayId >= 0 && action.relayId < NUM_RELAYS) {
        // Изменяем состояние реле
        relayStates[action.relayId] = action.turnOn;
        digitalWrite(relayPins[action.relayId], action.turnOn ? HIGH : LOW);
        
        // Сохраняем состояние в EEPROM
        saveRelayStates();
        
        // Обновляем экран
        if (currentDisplayPage == 1) {
          displayRelayStatus();
        } else if (currentDisplayPage == 2 && scenarioRunning) {
          drawPage3(); // Обновляем страницу статуса сценария
        }
      }
      
      // Переходим к следующему действию
      currentActionIndex++;
      
      // Обновляем отображение прогресса
      if (currentDisplayPage == 2 && scenarioRunning) {
        drawPage3();
      }
      
      // Если есть еще действия, устанавливаем время для следующего
      if (currentActionIndex < pendingActionsCount) {
        ScenarioAction nextAction = pendingActions[currentActionIndex];
        nextActionTime = millis() + nextAction.delayMs;
      } else {
        // Сценарий завершен
        scenarioRunning = false;
        Serial.println("Выполнение сценария завершено");
        
        // Если были на странице сценария, переключаемся на статус реле
        if (currentDisplayPage == 2) {
          currentDisplayPage = 1;
          displayRelayStatus();
        }
      }
    }
  }
}

// Обработчик для запуска сценария
void handleRunScenario() {
  recordActivity(); // Регистрируем активность
  
  // Проверяем, передан ли JSON
  if (!server.hasArg("plain")) {
    server.send(400, "text/plain; charset=utf-8", "Требуется JSON с описанием сценария");
    return;
  }
  
  // Получаем JSON из запроса
  String jsonString = server.arg("plain");
  
  DynamicJsonDocument doc(2048);
  DeserializationError error = deserializeJson(doc, jsonString);
  
  if (error) {
    String errorMsg = "Ошибка парсинга JSON: " + String(error.c_str());
    server.send(400, "text/plain; charset=utf-8", errorMsg);
    return;
  }
  
  // Проверяем, что передан массив действий
  if (!doc.containsKey("actions") || !doc["actions"].is<JsonArray>()) {
    server.send(400, "text/plain; charset=utf-8", "JSON должен содержать массив actions");
    return;
  }
  
  // Очищаем предыдущие действия
  pendingActionsCount = 0;
  
  // Парсим действия
  JsonArray actions = doc["actions"];
  for (JsonVariant actionVar : actions) {
    if (!actionVar.is<JsonObject>()) continue;
    
    JsonObject actionObj = actionVar.as<JsonObject>();
    
    // Проверяем наличие обязательных полей
    if (!actionObj.containsKey("relayId") || !actionObj.containsKey("turnOn")) {
      continue;
    }
    
    // Создаем действие
    ScenarioAction action;
    action.relayId = actionObj["relayId"].as<int>();
    action.turnOn = actionObj["turnOn"].as<bool>();
    action.delayMs = actionObj.containsKey("delayMs") ? actionObj["delayMs"].as<int>() : 0;
    
    // Добавляем действие, если еще есть место и реле с таким ID существует
    if (pendingActionsCount < 10 && action.relayId >= 0 && action.relayId < NUM_RELAYS) {
      pendingActions[pendingActionsCount++] = action;
    }
  }
  
  // Если есть действия, запускаем выполнение
  if (pendingActionsCount > 0) {
    // Сбрасываем индекс и запускаем сценарий
    currentActionIndex = 0;
    scenarioRunning = true;
    nextActionTime = millis(); // Первое действие запускаем сразу
    
    // Отображаем информацию о запуске сценария, если дисплей не спит
    if (!displaySleepMode) {
      u8g2.clearBuffer();
      u8g2.setCursor(0, 0);
      u8g2.print(F("Выполнение сценария"));
      u8g2.setCursor(0, 14);
      u8g2.print(F("Действий: "));
      u8g2.print(pendingActionsCount);
      u8g2.sendBuffer();
      
      // Устанавливаем таймер для возврата к обычному режиму отображения
      lastDisplayPageChange = millis();
    }
    
    Serial.print("Запуск сценария с ");
    Serial.print(pendingActionsCount);
    Serial.println(" действиями");
    
    server.send(200, "text/plain; charset=utf-8", "Сценарий запущен");
  } else {
    server.send(400, "text/plain; charset=utf-8", "Нет корректных действий для выполнения");
  }
}