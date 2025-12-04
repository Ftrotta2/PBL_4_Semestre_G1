/* imu_dual_wifi_v4_blindado.ino
   - 3 Sensores MPU6050
   - S1 e S2 no Hardware I2C 0 (Pinos 21, 22)
   - S3 no Hardware I2C 1 (Pinos 26, 27)
   - IP Fixo: 192.168.137.50
   
   ATUALIZAÇÕES DE SEGURANÇA:
   1. Timeout na leitura I2C (Impede travamento se o fio soltar)
   2. Clock I2C reduzido para 100kHz (Mais estável para fios longos)
*/

#include <WiFi.h>
#include <Wire.h>

#define WIFI_SSID "pcbruno"
#define WIFI_PASS "23456789"
#define TCP_PORT 3333

// Endereços I2C
const uint8_t ADDR1 = 0x68;
const uint8_t ADDR2 = 0x69;
const uint8_t ADDR3 = 0x68; // S3 no segundo barramento

// Pinos do Segundo Barramento (S3)
#define SENSOR3_SDA_PIN 26
#define SENSOR3_SCL_PIN 27

// Registradores
#define PWR_MGMT_1 0x6B
#define ACCEL_XOUT_H 0x3B
#define GYRO_XOUT_H  0x43

WiFiServer server(TCP_PORT);
WiFiClient client;

unsigned long lastSampleMs = 0;
const int SAMPLE_HZ = 50;
const unsigned long SAMPLE_MS = 1000 / SAMPLE_HZ;
unsigned long lastHeartbeat = 0;
const unsigned long HEART_MS = 1000;

// Filtro
struct Ori { float pitch, roll, yaw; unsigned long lastMicros; };
Ori s1 = {0,0,0,0}, s2 = {0,0,0,0}, s3 = {0,0,0,0};
const float alpha = 0.98;
const float accelScale = 16384.0;
const float gyroScale = 131.0;

// Offsets
long gx1_offset=0, gy1_offset=0, gz1_offset=0;
long gx2_offset=0, gy2_offset=0, gz2_offset=0;
long gx3_offset=0, gy3_offset=0, gz3_offset=0;

// Zero
float s1_pitch_offset=0, s1_roll_offset=0, s1_yaw_offset=0;
float s2_pitch_offset=0, s2_roll_offset=0, s2_yaw_offset=0;
float s3_pitch_offset=0, s3_roll_offset=0, s3_yaw_offset=0;

bool isCalibrated = false;
bool isZeroed = false;

// --- FUNÇÃO HELPER MODIFICADA (COM TIMEOUT) ---
int16_t read16(TwoWire& bus, uint8_t devAddr, uint8_t reg) {
  bus.beginTransmission(devAddr);
  bus.write(reg);
  bus.endTransmission(false);
  bus.requestFrom((int)devAddr, 2);
  
  // --- SOLUÇÃO 1: TIMEOUT PARA NÃO TRAVAR ---
  unsigned long start = millis();
  while (bus.available() < 2) {
    // Se demorar mais de 5ms para responder, desiste e retorna 0.
    // Isso evita que o código fique preso num loop infinito.
    if (millis() - start > 5) return 0; 
  }
  // ------------------------------------------
  
  uint8_t hi = bus.read();
  uint8_t lo = bus.read();
  return (int16_t)((hi << 8) | lo);
}

void mpu_wake(TwoWire& bus, uint8_t addr) {
  bus.beginTransmission(addr);
  bus.write(PWR_MGMT_1);
  bus.write(0x00);
  bus.endTransmission();
}

void calibrate_sensors() {
  Serial.println("Calibrando... Mantenha PARADO.");
  if(client && client.connected()) client.print("{\"type\":\"CAL_START\"}\n");
  
  const int num = 500;
  gx1_offset=0; gy1_offset=0; gz1_offset=0;
  gx2_offset=0; gy2_offset=0; gz2_offset=0;
  gx3_offset=0; gy3_offset=0; gz3_offset=0;
  
  for (int i = 0; i < num; i++) {
    gx1_offset += read16(Wire, ADDR1, GYRO_XOUT_H);
    gy1_offset += read16(Wire, ADDR1, GYRO_XOUT_H + 2);
    gz1_offset += read16(Wire, ADDR1, GYRO_XOUT_H + 4);
    gx2_offset += read16(Wire, ADDR2, GYRO_XOUT_H);
    gy2_offset += read16(Wire, ADDR2, GYRO_XOUT_H + 2);
    gz2_offset += read16(Wire, ADDR2, GYRO_XOUT_H + 4);
    gx3_offset += read16(Wire1, ADDR3, GYRO_XOUT_H);
    gy3_offset += read16(Wire1, ADDR3, GYRO_XOUT_H + 2);
    gz3_offset += read16(Wire1, ADDR3, GYRO_XOUT_H + 4);
    delay(3);
  }
  gx1_offset/=num; gy1_offset/=num; gz1_offset/=num;
  gx2_offset/=num; gy2_offset/=num; gz2_offset/=num;
  gx3_offset/=num; gy3_offset/=num; gz3_offset/=num;

  Serial.println("Calibrado!");
  if(client && client.connected()) client.print("{\"type\":\"CAL_DONE\"}\n");
}

void set_zero_offsets() {
  Serial.println("Zerando posição...");
  s1_pitch_offset = s1.pitch; s1_roll_offset = s1.roll; s1_yaw_offset = s1.yaw;
  s2_pitch_offset = s2.pitch; s2_roll_offset = s2.roll; s2_yaw_offset = s2.yaw;
  s3_pitch_offset = s3.pitch; s3_roll_offset = s3.roll; s3_yaw_offset = s3.yaw;
  
  if(client && client.connected()) client.print("{\"type\":\"ZERO_DONE\"}\n");
}

void setup() {
  Serial.begin(115200);
  
  // --- SOLUÇÃO 2: VELOCIDADE REDUZIDA (100kHz) ---
  // Isso ajuda muito com fios longos
  Wire.begin(); 
  Wire.setClock(100000); 
  
  Wire1.begin(SENSOR3_SDA_PIN, SENSOR3_SCL_PIN);
  Wire1.setClock(100000);
  // -----------------------------------------------
  
  Serial.println("ESP32 Start");
  mpu_wake(Wire, ADDR1); delay(10);
  mpu_wake(Wire, ADDR2); delay(10);
  mpu_wake(Wire1, ADDR3); delay(10);

  WiFi.mode(WIFI_STA);
  IPAddress local_IP(192, 168, 137, 50);
  IPAddress gateway(192, 168, 137, 1);
  IPAddress subnet(255, 255, 255, 0);
  IPAddress dns(8, 8, 8, 8);
  
  WiFi.config(local_IP, gateway, subnet, dns);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(300); Serial.print(".");
  }
  Serial.println("\nWiFi OK. IP: 192.168.137.50");
  
  server.begin();
  unsigned long m = micros();
  s1.lastMicros = m; s2.lastMicros = m; s3.lastMicros = m;
}

void loop() {
  if (!client || !client.connected()) {
    client = server.available();
    if (client && client.connected()) {
      Serial.println("App conectado!");
      isCalibrated = false; isZeroed = false;
    }
  }

  if (client && client.connected() && client.available()) {
    char c = client.read();
    if (c == 'c' && !isCalibrated) { calibrate_sensors(); isCalibrated = true; }
    else if (c == 'z' && isCalibrated) { set_zero_offsets(); isZeroed = true; }
  }

  unsigned long now = millis();
  if (now - lastHeartbeat >= HEART_MS) {
    lastHeartbeat = now;
    if (client && client.connected()) client.printf("{\"type\":\"HEARTBEAT\",\"t\":%lu}\n", now);
  }

  if (!isCalibrated) return;
  if (now - lastSampleMs < SAMPLE_MS) return;
  lastSampleMs = now;

  // Leitura
  int16_t ax1 = read16(Wire, ADDR1, ACCEL_XOUT_H), ay1 = read16(Wire, ADDR1, ACCEL_XOUT_H + 2), az1 = read16(Wire, ADDR1, ACCEL_XOUT_H + 4);
  int16_t gx1 = read16(Wire, ADDR1, GYRO_XOUT_H) - gx1_offset, gy1 = read16(Wire, ADDR1, GYRO_XOUT_H + 2) - gy1_offset, gz1 = read16(Wire, ADDR1, GYRO_XOUT_H + 4) - gz1_offset;

  int16_t ax2 = read16(Wire, ADDR2, ACCEL_XOUT_H), ay2 = read16(Wire, ADDR2, ACCEL_XOUT_H + 2), az2 = read16(Wire, ADDR2, ACCEL_XOUT_H + 4);
  int16_t gx2 = read16(Wire, ADDR2, GYRO_XOUT_H) - gx2_offset, gy2 = read16(Wire, ADDR2, GYRO_XOUT_H + 2) - gy2_offset, gz2 = read16(Wire, ADDR2, GYRO_XOUT_H + 4) - gz2_offset;

  int16_t ax3 = read16(Wire1, ADDR3, ACCEL_XOUT_H), ay3 = read16(Wire1, ADDR3, ACCEL_XOUT_H + 2), az3 = read16(Wire1, ADDR3, ACCEL_XOUT_H + 4);
  int16_t gx3 = read16(Wire1, ADDR3, GYRO_XOUT_H) - gx3_offset, gy3 = read16(Wire1, ADDR3, GYRO_XOUT_H + 2) - gy3_offset, gz3 = read16(Wire1, ADDR3, GYRO_XOUT_H + 4) - gz3_offset;

  // Conversão
  float ax1g=(float)ax1/accelScale, ay1g=(float)ay1/accelScale, az1g=(float)az1/accelScale;
  float gx1s=(float)gx1/gyroScale, gy1s=(float)gy1/gyroScale, gz1s=(float)gz1/gyroScale;
  
  float ax2g=(float)ax2/accelScale, ay2g=(float)ay2/accelScale, az2g=(float)az2/accelScale;
  float gx2s=(float)gx2/gyroScale, gy2s=(float)gy2/gyroScale, gz2s=(float)gz2/gyroScale;
  
  float ax3g=(float)ax3/accelScale, ay3g=(float)ay3/accelScale, az3g=(float)az3/accelScale;
  float gx3s=(float)gx3/gyroScale, gy3s=(float)gy3/gyroScale, gz3s=(float)gz3/gyroScale;

  // Filtro
  unsigned long tMicros = micros();
  float dt1=(tMicros-s1.lastMicros)*1e-6; if(dt1<=0) dt1=0.001;
  float dt2=(tMicros-s2.lastMicros)*1e-6; if(dt2<=0) dt2=0.001;
  float dt3=(tMicros-s3.lastMicros)*1e-6; if(dt3<=0) dt3=0.001;

  float pitchAcc1 = atan2(ay1g, sqrt(ax1g*ax1g + az1g*az1g)) * 180.0/PI;
  float rollAcc1  = atan2(-ax1g, az1g) * 180.0/PI;
  s1.pitch = alpha*(s1.pitch + gx1s*dt1) + (1.0-alpha)*pitchAcc1;
  s1.roll  = alpha*(s1.roll + gy1s*dt1) + (1.0-alpha)*rollAcc1;
  s1.yaw   += gz1s*dt1;

  float pitchAcc2 = atan2(ay2g, sqrt(ax2g*ax2g + az2g*az2g)) * 180.0/PI;
  float rollAcc2  = atan2(-ax2g, az2g) * 180.0/PI;
  s2.pitch = alpha*(s2.pitch + gx2s*dt2) + (1.0-alpha)*pitchAcc2;
  s2.roll  = alpha*(s2.roll + gy2s*dt2) + (1.0-alpha)*rollAcc2;
  s2.yaw   += gz2s*dt2;

  float pitchAcc3 = atan2(ay3g, sqrt(ax3g*ax3g + az3g*az3g)) * 180.0/PI;
  float rollAcc3  = atan2(-ax3g, az3g) * 180.0/PI;
  s3.pitch = alpha*(s3.pitch + gx3s*dt3) + (1.0-alpha)*pitchAcc3;
  s3.roll  = alpha*(s3.roll + gy3s*dt3) + (1.0-alpha)*rollAcc3;
  s3.yaw   += gz3s*dt3;

  s1.lastMicros=tMicros; s2.lastMicros=tMicros; s3.lastMicros=tMicros;

  // Smoothing
  const float lpA = 0.6;
  static float p1=0, r1=0, y1=0, p2=0, r2=0, y2=0, p3=0, r3=0, y3=0;
  p1 = lpA*p1 + (1-lpA)*s1.pitch; r1 = lpA*r1 + (1-lpA)*s1.roll; y1 = lpA*y1 + (1-lpA)*s1.yaw;
  p2 = lpA*p2 + (1-lpA)*s2.pitch; r2 = lpA*r2 + (1-lpA)*s2.roll; y2 = lpA*y2 + (1-lpA)*s2.yaw;
  p3 = lpA*p3 + (1-lpA)*s3.pitch; r3 = lpA*r3 + (1-lpA)*s3.roll; y3 = lpA*y3 + (1-lpA)*s3.yaw;

  if (!isZeroed) return;

  // JSON
  char jbuf[384];
  snprintf(jbuf, sizeof(jbuf),
    "{\"sensor1\":{\"pitch\":%.3f,\"roll\":%.3f,\"yaw\":%.3f},"
    "\"sensor2\":{\"pitch\":%.3f,\"roll\":%.3f,\"yaw\":%.3f},"
    "\"sensor3\":{\"pitch\":%.3f,\"roll\":%.3f,\"yaw\":%.3f},\"t\":%lu}\n",
    p1 - s1_pitch_offset, r1 - s1_roll_offset, y1 - s1_yaw_offset,
    p2 - s2_pitch_offset, r2 - s2_roll_offset, y2 - s2_yaw_offset,
    p3 - s3_pitch_offset, r3 - s3_roll_offset, y3 - s3_yaw_offset, 
    millis());
  
  if (client && client.connected()) {
    client.print(jbuf);
  }
  
  // Debug (para ver se não está travando)
  static unsigned long lp = 0;
  if (millis() - lp > 1000) {
    Serial.print("Data -> "); Serial.println(jbuf);
    lp = millis();
  }
}