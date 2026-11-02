#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <LittleFS.h>
#include <Preferences.h>
#include <Wire.h>
#include <math.h>

class MPU6050Simple;
struct Posture;

enum PostureState { POSTURE_OK = 0, POSTURE_SLOUCH = 1 };
enum LateralState { LATERAL_OK = 0, LATERAL_LEFT = 1, LATERAL_RIGHT = 2 };
enum ActivityState {
  ACT_UNKNOWN = 0,
  ACT_SITTING = 1,
  ACT_STANDING = 2,
  ACT_WALKING = 3,
  ACT_RUNNING = 4,
  ACT_LYING = 5,
  ACT_DEVICE_REMOVED = 6
};

static bool loadCalibNVS(MPU6050Simple &upper, MPU6050Simple &lower,
                         Posture &posture);
static void saveCalibNVS(const MPU6050Simple &upper, const MPU6050Simple &lower,
                         const Posture &posture);

static const int PIN_SDA = 22;
static const int PIN_SCL = 21;
static const uint32_t I2C_FREQ = 100000;
static const uint8_t MPU_UPPER_ADDR = 0x69;
static const uint8_t MPU_LOWER_ADDR = 0x68;
static const int PIN_VIB = 13;
static const int PIN_CHARGE_DET = 18;
static const int PIN_BATT_ADC = 36;

static const float BATT_DIVIDER_RATIO = 1.0f;

static const float CHARGE_OFFSET = 0.20f;
static const float V_EMPTY = 2.40f;
static const float V_FULL = 2.80f;

static const int SAMPLE_RATE_HZ = 100;
static const int TELEMETRY_RATE_HZ = 4;

static float SLOUCH_THRESHOLD_DEG = 20.0f;
static const float POSTURE_HYSTERESIS_DEG = 3.0f;
static uint32_t SLOUCH_HOLD_MS = 5000;
static bool VIBRATION_ENABLED = true;
static const uint32_t RECOVER_HOLD_MS = 0;

static const float STEP_THRESHOLD_G = 0.20f;
static const uint32_t MIN_STEP_INTERVAL_MS = 300;
static const uint32_t INACTIVITY_ALERT_MS = 60UL * 60UL * 1000UL;
static const float WALK_DYN_THRESHOLD_G = 0.10f;
static const float RUN_DYN_THRESHOLD_G = 0.34f;
static const float STILL_DYN_THRESHOLD_G = 0.025f;
static const uint32_t WALK_RECENT_MS = 2500;
static const uint32_t STAND_RECENT_MS = 15000;
static const uint32_t DEVICE_REMOVED_CANDIDATE_MS = 60000;

static float LATERAL_THRESHOLD_DEG = 15.0f;
static uint32_t LATERAL_HOLD_MS = 4000;

static float SLUMP_LLA_THRESHOLD_DEG = 15.0f;
static float SLUMP_PELVIS_THRESHOLD_DEG = 15.0f;
static uint32_t SLUMP_HOLD_MS = 5000;

static const float ORI_ALPHA = 0.95f;

static const uint8_t REG_SMPLRT_DIV = 0x19;
static const uint8_t REG_CONFIG = 0x1A;
static const uint8_t REG_GYRO_CONFIG = 0x1B;
static const uint8_t REG_ACCEL_CONFIG = 0x1C;
static const uint8_t REG_PWR_MGMT_1 = 0x6B;
static const uint8_t REG_ACCEL_XOUT_H = 0x3B;

static const float ACC_LSB_PER_G = 16384.0f;
static const float GYRO_LSB_PER_DPS = 131.0f;

struct Vec3f {
  float x, y, z;
};
struct MpuSample {
  Vec3f acc_g;
  Vec3f gyro_dps;
};
struct Orientation {
  float pitch_deg = 0;
  float roll_deg = 0;
};
struct AxisMap {
  int8_t xi, yi, zi;
  int8_t xs, ys, zs;
};
static const AxisMap AXIS_UPPER = {0, 1, 2, +1, +1, +1};
static const AxisMap AXIS_LOWER = {0, 1, 2, +1, +1, +1};

struct SharedTelemetry {
  uint32_t timestampMs;
  float pitchUpper;
  float pitchLower;
  float deltaPitch;
  float rollUpper;
  float rollLower;
  float deltaRoll;
  int postureState;
  int lateralState;
  int activityState;
  bool isVibrating;
  uint32_t stepCount;
  float batteryVoltage;
  bool isCharging;
};

SharedTelemetry globalData;

struct OfflineRecord {
  uint32_t ts_millis;
  int16_t pu_x100;
  int16_t pl_x100;
  int16_t dp_x100;
  int16_t ru_x100;
  int16_t rl_x100;
  int16_t dr_x100;
  uint8_t st;
  uint8_t vib;
  uint8_t lat;
  uint8_t act;
  uint32_t stp;
  uint16_t bv_x100;
  uint8_t chg;
};

static const int OFFLINE_BATCH_SIZE = 50;
OfflineRecord offlineBuffer[OFFLINE_BATCH_SIZE];
int offlineBufferCount = 0;
bool isBulkSyncing = false;

SemaphoreHandle_t dataMutex;

int64_t timeOffsetMs = 0;

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
bool deviceConnected = false;

bool oldDeviceConnected = false;
volatile bool doCalibNow = false;
volatile bool saveConfigNow = false;
volatile bool triggeredFromBLE = false;
volatile bool pendingCalibResult = false;
volatile bool calibSuccess = false;

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    deviceConnected = true;
    Serial.println("[BLE] Cihaz bağlandı!");
  };
  void onDisconnect(BLEServer *pServer) {
    deviceConnected = false;
    Serial.println("[BLE] Cihaz koptu, yeniden başlama komutu bekleniyor...");
  }
};

class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      Serial.printf("[BLE] Gelen Veri: %s\n", rxValue.c_str());
      StaticJsonDocument<256> doc;
      DeserializationError error = deserializeJson(doc, rxValue);
      if (!error) {
        if (doc.containsKey("calibration") && doc["calibration"] == true) {
          triggeredFromBLE = true;
          doCalibNow = true;
        }
        if (doc.containsKey("delay")) {
          SLOUCH_HOLD_MS = doc["delay"].as<uint32_t>() * 1000;
          saveConfigNow = true;
        }
        if (doc.containsKey("vibration")) {
          VIBRATION_ENABLED = doc["vibration"].as<bool>();
          saveConfigNow = true;
        }
        if (doc.containsKey("thresholdAngle")) {
          SLOUCH_THRESHOLD_DEG = doc["thresholdAngle"].as<float>();
          saveConfigNow = true;
        }
        if (doc.containsKey("syncTime")) {
          uint64_t epochMs = doc["syncTime"].as<uint64_t>();
          timeOffsetMs = epochMs - millis();

          if (LittleFS.exists("/offline.dat") || offlineBufferCount > 0) {
            isBulkSyncing = true;
          }
        }
      }
    }
  }
};

void bleTelemetryTask(void *pvParameters) {

  for (;;) {
    if (pendingCalibResult && deviceConnected) {
      char calibMsg[64];
      snprintf(calibMsg, sizeof(calibMsg), "{\"calib_result\":%s}",
               calibSuccess ? "true" : "false");
      pCharacteristic->setValue((uint8_t *)calibMsg, strlen(calibMsg));
      pCharacteristic->notify();
      pendingCalibResult = false;
      vTaskDelay(pdMS_TO_TICKS(200));
    } else if (isBulkSyncing && deviceConnected) {

      if (offlineBufferCount > 0) {
        File f = LittleFS.open("/offline.dat", "a");
        if (f) {
          f.write((uint8_t *)offlineBuffer,
                  sizeof(OfflineRecord) * offlineBufferCount);
          f.close();
        }
        offlineBufferCount = 0;
      }

      pCharacteristic->setValue((uint8_t *)"{\"bulk\":\"start\"}", 16);
      pCharacteristic->notify();
      vTaskDelay(pdMS_TO_TICKS(200));

      File f = LittleFS.open("/offline.dat", "r");
      if (f) {
        OfflineRecord rec;
        while (f.read((uint8_t *)&rec, sizeof(OfflineRecord)) ==
               sizeof(OfflineRecord)) {
          if (!deviceConnected)
            break;
          Serial.println("\n[BULK SYNC] XXXXXXXXXXXXXXXXXX");
          StaticJsonDocument<384> bdoc;
          bdoc["ts"] = rec.ts_millis + timeOffsetMs;
          bdoc["pu"] = (int)(rec.pu_x100) / 100.0;
          bdoc["pl"] = (int)(rec.pl_x100) / 100.0;
          bdoc["dp"] = (int)(rec.dp_x100) / 100.0;
          bdoc["ru"] = (int)(rec.ru_x100) / 100.0;
          bdoc["rl"] = (int)(rec.rl_x100) / 100.0;
          bdoc["dr"] = (int)(rec.dr_x100) / 100.0;
          bdoc["st"] = rec.st;
          bdoc["vib"] = rec.vib;
          bdoc["stp"] = rec.stp;
          bdoc["sit"] =
              (rec.act == ACT_SITTING || rec.act == ACT_LYING) ? 1 : 0;
          int bvpct =
              (int)(((rec.bv_x100 / 100.0f) - 3.3f) / (4.2f - 3.3f) * 100.0f);
          if (bvpct < 0)
            bvpct = 0;
          if (bvpct > 100)
            bvpct = 100;
          bdoc["bv"] = bvpct;
          bdoc["chg"] = (bool)rec.chg;

          char bjson[384];
          serializeJson(bdoc, bjson);
          pCharacteristic->setValue((uint8_t *)bjson, strlen(bjson));
          pCharacteristic->notify();

          vTaskDelay(pdMS_TO_TICKS(40));
        }
        f.close();
      }

      if (deviceConnected) {
        vTaskDelay(pdMS_TO_TICKS(100));
        pCharacteristic->setValue((uint8_t *)"{\"bulk\":\"end\"}", 14);
        pCharacteristic->notify();
        vTaskDelay(pdMS_TO_TICKS(200));
      }
      LittleFS.remove("/offline.dat");
      isBulkSyncing = false;

    } else if (deviceConnected) {

      SharedTelemetry localData;
      if (xSemaphoreTake(dataMutex, portMAX_DELAY) == pdTRUE) {
        localData = globalData;
        xSemaphoreGive(dataMutex);
      }

      StaticJsonDocument<384> doc;
      doc["ts"] = localData.timestampMs + timeOffsetMs;
      doc["pu"] = (int)(localData.pitchUpper * 100) / 100.0;
      doc["pl"] = (int)(localData.pitchLower * 100) / 100.0;
      doc["dp"] = (int)(localData.deltaPitch * 100) / 100.0;
      doc["ru"] = (int)(localData.rollUpper * 100) / 100.0;
      doc["rl"] = (int)(localData.rollLower * 100) / 100.0;
      doc["dr"] = (int)(localData.deltaRoll * 100) / 100.0;
      doc["st"] = localData.postureState;
      doc["vib"] = localData.isVibrating;
      doc["stp"] = localData.stepCount;
      doc["sit"] = (localData.activityState == ACT_SITTING ||
                    localData.activityState == ACT_LYING)
                       ? 1
                       : 0;

      int pct = batteryPercent(localData.batteryVoltage, localData.isCharging);
      doc["bv"] = pct;
      doc["chg"] = localData.isCharging;

      char jsonBuffer[384];
      serializeJson(doc, jsonBuffer);

      pCharacteristic->setValue((uint8_t *)jsonBuffer, strlen(jsonBuffer));
      pCharacteristic->notify();

      vTaskDelay(pdMS_TO_TICKS(1000 / TELEMETRY_RATE_HZ));

    } else {

      SharedTelemetry localData;
      if (xSemaphoreTake(dataMutex, portMAX_DELAY) == pdTRUE) {
        localData = globalData;
        xSemaphoreGive(dataMutex);
      }

      offlineBuffer[offlineBufferCount].ts_millis = localData.timestampMs;
      offlineBuffer[offlineBufferCount].pu_x100 =
          (int16_t)(localData.pitchUpper * 100);
      offlineBuffer[offlineBufferCount].pl_x100 =
          (int16_t)(localData.pitchLower * 100);
      offlineBuffer[offlineBufferCount].dp_x100 =
          (int16_t)(localData.deltaPitch * 100);
      offlineBuffer[offlineBufferCount].ru_x100 =
          (int16_t)(localData.rollUpper * 100);
      offlineBuffer[offlineBufferCount].rl_x100 =
          (int16_t)(localData.rollLower * 100);
      offlineBuffer[offlineBufferCount].dr_x100 =
          (int16_t)(localData.deltaRoll * 100);
      offlineBuffer[offlineBufferCount].st = (uint8_t)localData.postureState;
      offlineBuffer[offlineBufferCount].vib = (uint8_t)localData.isVibrating;
      offlineBuffer[offlineBufferCount].lat = (uint8_t)localData.lateralState;
      offlineBuffer[offlineBufferCount].act = (uint8_t)localData.activityState;
      offlineBuffer[offlineBufferCount].stp = localData.stepCount;
      offlineBuffer[offlineBufferCount].bv_x100 =
          (uint16_t)(localData.batteryVoltage * 100);
      offlineBuffer[offlineBufferCount].chg = (uint8_t)localData.isCharging;
      offlineBufferCount++;

      if (offlineBufferCount >= OFFLINE_BATCH_SIZE) {
        File f = LittleFS.open("/offline.dat", "a");
        if (f) {
          f.write((uint8_t *)offlineBuffer,
                  sizeof(OfflineRecord) * OFFLINE_BATCH_SIZE);
          f.close();
        }
        offlineBufferCount = 0;
      }

      vTaskDelay(pdMS_TO_TICKS(1000 / TELEMETRY_RATE_HZ));
    }
  }
}

static bool i2cWrite8(uint8_t addr, uint8_t reg, uint8_t val) {
  Wire.beginTransmission(addr);
  Wire.write(reg);
  Wire.write(val);
  return (Wire.endTransmission(true) == 0);
}

static bool i2cRead(uint8_t addr, uint8_t reg, uint8_t *buf, size_t len) {
  Wire.beginTransmission(addr);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0)
    return false;

  size_t got = Wire.requestFrom((int)addr, (int)len, (int)true);
  if (got != len)
    return false;

  for (size_t i = 0; i < len; i++) {
    buf[i] = Wire.read();
  }
  return true;
}

class MPU6050Simple {
public:
  MPU6050Simple(uint8_t address) : addr(address) {}

  bool begin() {
    if (!i2cWrite8(addr, REG_PWR_MGMT_1, 0x00))
      return false;
    delay(50);
    if (!i2cWrite8(addr, REG_CONFIG, 0x03))
      return false;
    if (!i2cWrite8(addr, REG_SMPLRT_DIV, 9))
      return false;
    if (!i2cWrite8(addr, REG_GYRO_CONFIG, 0x00))
      return false;
    if (!i2cWrite8(addr, REG_ACCEL_CONFIG, 0x00))
      return false;
    return true;
  }

  bool readSample(MpuSample &out) {
    uint8_t buf[14];
    if (!i2cRead(addr, REG_ACCEL_XOUT_H, buf, sizeof(buf)))
      return false;

    int16_t ax = (int16_t)((buf[0] << 8) | buf[1]);
    int16_t ay = (int16_t)((buf[2] << 8) | buf[3]);
    int16_t az = (int16_t)((buf[4] << 8) | buf[5]);
    int16_t gx = (int16_t)((buf[8] << 8) | buf[9]);
    int16_t gy = (int16_t)((buf[10] << 8) | buf[11]);
    int16_t gz = (int16_t)((buf[12] << 8) | buf[13]);

    out.acc_g.x = (float)ax / ACC_LSB_PER_G;
    out.acc_g.y = (float)ay / ACC_LSB_PER_G;
    out.acc_g.z = (float)az / ACC_LSB_PER_G;

    out.gyro_dps.x = (float)gx / GYRO_LSB_PER_DPS - gyroBias[0];
    out.gyro_dps.y = (float)gy / GYRO_LSB_PER_DPS - gyroBias[1];
    out.gyro_dps.z = (float)gz / GYRO_LSB_PER_DPS - gyroBias[2];

    return true;
  }

  void setGyroBias(float bx, float by, float bz) {
    gyroBias[0] = bx;
    gyroBias[1] = by;
    gyroBias[2] = bz;
  }

  void getGyroBias(float &bx, float &by, float &bz) const {
    bx = gyroBias[0];
    by = gyroBias[1];
    bz = gyroBias[2];
  }

  bool calibrateGyro(int sampleCount, int delayMs) {
    double sx = 0, sy = 0, sz = 0;
    float oldBx = gyroBias[0], oldBy = gyroBias[1], oldBz = gyroBias[2];
    gyroBias[0] = 0;
    gyroBias[1] = 0;
    gyroBias[2] = 0;

    for (int i = 0; i < sampleCount; i++) {
      MpuSample s;
      if (!readSample(s)) {
        gyroBias[0] = oldBx;
        gyroBias[1] = oldBy;
        gyroBias[2] = oldBz;
        return false;
      }
      sx += s.gyro_dps.x;
      sy += s.gyro_dps.y;
      sz += s.gyro_dps.z;
      delay(delayMs);
    }
    gyroBias[0] = (float)(sx / sampleCount);
    gyroBias[1] = (float)(sy / sampleCount);
    gyroBias[2] = (float)(sz / sampleCount);
    return true;
  }

private:
  uint8_t addr;
  float gyroBias[3] = {0, 0, 0};
};

static void applyAxisMap(const AxisMap &m, const Vec3f &in, Vec3f &out) {
  float raw[3] = {in.x, in.y, in.z};
  out.x = (float)m.xs * raw[(int)m.xi];
  out.y = (float)m.ys * raw[(int)m.yi];
  out.z = (float)m.zs * raw[(int)m.zi];
}

static float rad2deg(float r) { return r * (180.0f / (float)M_PI); }

static void orientationUpdate(Orientation &o, const Vec3f &acc_g,
                              const Vec3f &gyro_dps, float dt, float alpha) {
  float ax = acc_g.x, ay = acc_g.y, az = acc_g.z;

  if ((ax * ax + ay * ay + az * az) < 0.01f)
    return;

  float roll_acc = rad2deg(atan2f(ay, az));
  float pitch_acc = rad2deg(atan2f(-ax, sqrtf(ay * ay + az * az)));

  o.roll_deg =
      alpha * (o.roll_deg + gyro_dps.x * dt) + (1.0f - alpha) * roll_acc;
  o.pitch_deg =
      alpha * (o.pitch_deg + gyro_dps.y * dt) + (1.0f - alpha) * pitch_acc;
}

static float vecMag(const Vec3f &v) {
  return sqrtf(v.x * v.x + v.y * v.y + v.z * v.z);
}

struct Posture {
  float baselinePitchUpper = 0;
  float baselinePitchLower = 0;
  float baselineDeltaPitch = 0;
  float baselineRollUpper = 0;
  float baselineRollLower = 0;
  float baselineDeltaRoll = 0;

  PostureState state = POSTURE_OK;
  uint32_t slouchStartMs = 0;
  uint32_t recoverStartMs = 0;

  void setBaseline(float pu, float pl, float ru = 0, float rl = 0) {
    baselinePitchUpper = pu;
    baselinePitchLower = pl;
    baselineDeltaPitch = pu - pl;
    baselineRollUpper = ru;
    baselineRollLower = rl;
    baselineDeltaRoll = ru - rl;
  }

  void reset() {
    state = POSTURE_OK;
    slouchStartMs = 0;
    recoverStartMs = 0;
  }

  void update(uint32_t nowMs, float pitchUpper, float pitchLower,
              float &deltaOut) {
    float delta = pitchUpper - pitchLower;
    deltaOut = delta;

    bool slouchCond = fabsf(delta - baselineDeltaPitch) > SLOUCH_THRESHOLD_DEG;

    if (state == POSTURE_OK) {
      if (slouchCond) {
        if (slouchStartMs == 0)
          slouchStartMs = nowMs;
        if ((nowMs - slouchStartMs) >= SLOUCH_HOLD_MS) {
          state = POSTURE_SLOUCH;
          recoverStartMs = 0;
        }
      } else {
        slouchStartMs = 0;
      }
    } else {
      if (!slouchCond) {
        if (recoverStartMs == 0)
          recoverStartMs = nowMs;
        if ((nowMs - recoverStartMs) >= RECOVER_HOLD_MS) {
          state = POSTURE_OK;
          slouchStartMs = 0;
        }
      } else {
        recoverStartMs = 0;
      }
    }
  }
};

struct LateralPosture {
  LateralState state = LATERAL_OK;
  uint32_t leanStartMs = 0;
  uint32_t recoverStartMs = 0;

  void reset() {
    state = LATERAL_OK;
    leanStartMs = 0;
    recoverStartMs = 0;
  }

  void update(uint32_t nowMs, float rollUpper, float rollLower,
              float baselineDeltaRoll, float &deltaOut) {
    float delta = rollUpper - rollLower;
    deltaOut = delta;
    float err = delta - baselineDeltaRoll;
    bool leanCond = fabsf(err) > LATERAL_THRESHOLD_DEG;

    if (state == LATERAL_OK) {
      if (leanCond) {
        if (leanStartMs == 0)
          leanStartMs = nowMs;
        if ((nowMs - leanStartMs) >= LATERAL_HOLD_MS) {
          state = (err > 0) ? LATERAL_RIGHT : LATERAL_LEFT;
          recoverStartMs = 0;
        }
      } else {
        leanStartMs = 0;
      }
    } else {
      if (!leanCond) {
        if (recoverStartMs == 0)
          recoverStartMs = nowMs;
        if ((nowMs - recoverStartMs) >= RECOVER_HOLD_MS) {
          reset();
        }
      } else {
        state = (err > 0) ? LATERAL_RIGHT : LATERAL_LEFT;
        recoverStartMs = 0;
      }
    }
  }
};

struct SlumpPosture {
  bool state = false;
  uint32_t slumpStartMs = 0;
  uint32_t recoverStartMs = 0;

  void reset() {
    state = false;
    slumpStartMs = 0;
    recoverStartMs = 0;
  }

  void update(uint32_t nowMs, float deltaPitch, float baselineDeltaPitch,
              float pitchLower, float baselinePitchLower) {
    float pelvisDelta = fabsf(pitchLower - baselinePitchLower);
    bool slumpCond =
        ((deltaPitch - baselineDeltaPitch) < -SLUMP_LLA_THRESHOLD_DEG) ||
        (pelvisDelta > SLUMP_PELVIS_THRESHOLD_DEG);

    if (!state) {
      if (slumpCond) {
        if (slumpStartMs == 0)
          slumpStartMs = nowMs;
        if ((nowMs - slumpStartMs) >= SLUMP_HOLD_MS) {
          state = true;
          recoverStartMs = 0;
        }
      } else {
        slumpStartMs = 0;
      }
    } else {
      if (!slumpCond) {
        if (recoverStartMs == 0)
          recoverStartMs = nowMs;
        if ((nowMs - recoverStartMs) >= RECOVER_HOLD_MS) {
          state = false;
          slumpStartMs = 0;
        }
      } else {
        recoverStartMs = 0;
      }
    }
  }
};

struct Activity {
  uint32_t steps = 0;
  float lpDyn = 0;
  float lastStepIntervalMs = 0;
  uint32_t lastStepMs = 0;
  uint32_t lastActivityMs = 0;
  uint32_t lastInactAlertMs = 0;
  uint32_t removedCandidateStartMs = 0;
  ActivityState state = ACT_UNKNOWN;
  float meanLower = 1.0f;
  float meanUpper = 1.0f;

  void update(uint32_t nowMs, float accelMagLowerG, float accelMagUpperG,
              float gyroMagDps, float pitchUpper, float pitchLower,
              float rollUpper, float rollLower, const Posture &posture) {
    if (lastActivityMs == 0)
      lastActivityMs = nowMs;

    if (meanLower < 0.1f)
      meanLower = accelMagLowerG;
    else
      meanLower = 0.995f * meanLower + 0.005f * accelMagLowerG;

    if (meanUpper < 0.1f)
      meanUpper = accelMagUpperG;
    else
      meanUpper = 0.995f * meanUpper + 0.005f * accelMagUpperG;

    float dynLower = fabsf(accelMagLowerG - meanLower);
    float dynUpper = fabsf(accelMagUpperG - meanUpper);
    float dyn = fmaxf(dynLower, dynUpper);
    lpDyn = 0.85f * lpDyn + 0.15f * dyn;

    bool isVibrating = (digitalRead(PIN_VIB) == HIGH);

    if (lpDyn > STEP_THRESHOLD_G && !isVibrating) {
      if (lastStepMs == 0 || (nowMs - lastStepMs) >= MIN_STEP_INTERVAL_MS) {
        if (lastStepMs != 0)
          lastStepIntervalMs = (float)(nowMs - lastStepMs);
        steps++;
        lastStepMs = nowMs;
        lastActivityMs = nowMs;
      }
    }

    if (lpDyn > WALK_DYN_THRESHOLD_G || gyroMagDps > 18.0f) {
      lastActivityMs = nowMs;
    }

    float pitchMove = fmaxf(fabsf(pitchUpper - posture.baselinePitchUpper),
                            fabsf(pitchLower - posture.baselinePitchLower));
    float rollMove = fmaxf(fabsf(rollUpper - posture.baselineRollUpper),
                           fabsf(rollLower - posture.baselineRollLower));
    bool lyingCandidate = (pitchMove > 55.0f || rollMove > 50.0f);
    bool sameSensorPlane = fabsf(pitchUpper - pitchLower) < 4.0f &&
                           fabsf(rollUpper - rollLower) < 4.0f;

    if (lyingCandidate && sameSensorPlane && lpDyn < STILL_DYN_THRESHOLD_G) {
      if (removedCandidateStartMs == 0)
        removedCandidateStartMs = nowMs;
    } else {
      removedCandidateStartMs = 0;
    }

    bool recentWalkStep =
        lastStepMs != 0 && (nowMs - lastStepMs) < WALK_RECENT_MS;
    bool recentStandStep =
        lastStepMs != 0 && (nowMs - lastStepMs) < STAND_RECENT_MS;

    if (removedCandidateStartMs != 0 &&
        (nowMs - removedCandidateStartMs) >= DEVICE_REMOVED_CANDIDATE_MS) {
      state = ACT_DEVICE_REMOVED;
    } else if (lyingCandidate) {
      state = ACT_LYING;
    } else if (lpDyn > RUN_DYN_THRESHOLD_G ||
               (lastStepIntervalMs > 0 && lastStepIntervalMs < 470 &&
                recentWalkStep)) {
      state = ACT_RUNNING;
    } else if (recentWalkStep || lpDyn > WALK_DYN_THRESHOLD_G) {
      state = ACT_WALKING;
    } else if (recentStandStep) {
      state = ACT_STANDING;
    } else {
      state = ACT_SITTING;
    }
  }
};

Preferences prefs;

static bool loadCalibNVS(MPU6050Simple &upper, MPU6050Simple &lower,
                         Posture &posture) {
  prefs.begin("calib", true);
  bool valid = prefs.getBool("valid", false);
  if (!valid) {
    prefs.end();
    return false;
  }

  upper.setGyroBias(prefs.getFloat("bu0", 0), prefs.getFloat("bu1", 0),
                    prefs.getFloat("bu2", 0));
  lower.setGyroBias(prefs.getFloat("bl0", 0), prefs.getFloat("bl1", 0),
                    prefs.getFloat("bl2", 0));
  bool hasRollBaseline = prefs.isKey("ru0") && prefs.isKey("rl0");
  if (!hasRollBaseline) {
    prefs.end();
    return false;
  }

  posture.setBaseline(prefs.getFloat("pu0", 0), prefs.getFloat("pl0", 0),
                      prefs.getFloat("ru0", 0), prefs.getFloat("rl0", 0));
  SLOUCH_THRESHOLD_DEG = prefs.getFloat("thr", SLOUCH_THRESHOLD_DEG);
  SLOUCH_HOLD_MS = prefs.getUInt("delayMs", SLOUCH_HOLD_MS);

  prefs.end();
  return true;
}

static void saveCalibNVS(const MPU6050Simple &upper, const MPU6050Simple &lower,
                         const Posture &posture) {
  float bu0, bu1, bu2, bl0, bl1, bl2;
  upper.getGyroBias(bu0, bu1, bu2);
  lower.getGyroBias(bl0, bl1, bl2);

  prefs.begin("calib", false);
  prefs.putBool("valid", true);

  prefs.putFloat("bu0", bu0);
  prefs.putFloat("bu1", bu1);
  prefs.putFloat("bu2", bu2);
  prefs.putFloat("bl0", bl0);
  prefs.putFloat("bl1", bl1);
  prefs.putFloat("bl2", bl2);
  prefs.putFloat("pu0", posture.baselinePitchUpper);
  prefs.putFloat("pl0", posture.baselinePitchLower);
  prefs.putFloat("ru0", posture.baselineRollUpper);
  prefs.putFloat("rl0", posture.baselineRollLower);
  prefs.putFloat("thr", SLOUCH_THRESHOLD_DEG);
  prefs.putUInt("delayMs", SLOUCH_HOLD_MS);
  prefs.putBool("vibEn", VIBRATION_ENABLED);

  prefs.end();
}

MPU6050Simple imuUpper(MPU_UPPER_ADDR);
MPU6050Simple imuLower(MPU_LOWER_ADDR);

Orientation oriUpper, oriLower;
Posture posture;
LateralPosture lateralPosture;
SlumpPosture slumpPosture;
Activity activity;

static float readBatteryVoltage() {
  int raw = analogRead(PIN_BATT_ADC);

  return (raw / 4095.0f) * 3.3f;
}

static int batteryPercent(float v, bool charging) {
  float corrected = charging ? (v - CHARGE_OFFSET) : v;
  float pct = (corrected - V_EMPTY) / (V_FULL - V_EMPTY) * 100.0f;
  if (pct < 0)
    pct = 0;
  if (pct > 100)
    pct = 100;
  return (int)pct;
}

static bool doCalibration() {
  Serial.println("\n[CALIB] Cihaz SABIT ve DOGRU DURUS pozisyonunda kalsin...");
  delay(1500);

  if (!imuUpper.calibrateGyro(300, 10))
    return false;
  if (!imuLower.calibrateGyro(300, 10))
    return false;

  const int N = 200;
  double sumPu = 0, sumPl = 0, sumRu = 0, sumRl = 0;

  for (int i = 0; i < N; i++) {
    MpuSample su, sl;
    if (!imuUpper.readSample(su))
      return false;
    if (!imuLower.readSample(sl))
      return false;

    Vec3f accU_b, accL_b;
    applyAxisMap(AXIS_UPPER, su.acc_g, accU_b);
    applyAxisMap(AXIS_LOWER, sl.acc_g, accL_b);

    float pitchU = rad2deg(
        atan2f(-accU_b.x, sqrtf(accU_b.y * accU_b.y + accU_b.z * accU_b.z)));
    float pitchL = rad2deg(
        atan2f(-accL_b.x, sqrtf(accL_b.y * accL_b.y + accL_b.z * accL_b.z)));
    float rollU = rad2deg(atan2f(accU_b.y, accU_b.z));
    float rollL = rad2deg(atan2f(accL_b.y, accL_b.z));

    sumPu += pitchU;
    sumPl += pitchL;
    sumRu += rollU;
    sumRl += rollL;
    delay(10);
  }

  posture.setBaseline((float)(sumPu / N), (float)(sumPl / N),
                      (float)(sumRu / N), (float)(sumRl / N));
  saveCalibNVS(imuUpper, imuLower, posture);
  Serial.println("[CALIB] Kaydedildi.");
  return true;
}

static void handleSerial() {
  if (!Serial.available())
    return;
  String cmd = Serial.readStringUntil('\n');
  cmd.trim();
  if (cmd.length() == 0)
    return;

  if (cmd == "c" || cmd == "C") {
    doCalibration();

  } else if (cmd.startsWith("t") || cmd.startsWith("T")) {
    float v = cmd.substring(1).toFloat();
    if (v > 1.0f && v < 60.0f) {
      SLOUCH_THRESHOLD_DEG = v;
      saveCalibNVS(imuUpper, imuLower, posture);
    }
  }
}

uint32_t lastSampleMs = 0;
uint32_t lastTelMs = 0;

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println(">>> SISTEM BASLATILIYOR <<<");

  if (!LittleFS.begin(true)) {
    Serial.println("LittleFS Hatasi!");
  } else {
    Serial.println("LittleFS Tamam.");
  }

  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.setClock(I2C_FREQ);
  Wire.setTimeOut(50);
  Serial.println("I2C Hazir.");

  Serial.println("IMU Testi basliyor...");
  if (!imuUpper.begin())
    Serial.println("UST SENSOR BULUNAMADI (0x69)");
  else
    Serial.println("Ust sensor OK (0x69)");
  if (!imuLower.begin())
    Serial.println("ALT SENSOR BULUNAMADI (0x68)");
  else
    Serial.println("Alt sensor OK (0x68)");

  delay(50);

  pinMode(PIN_VIB, OUTPUT);
  digitalWrite(PIN_VIB, LOW);

  pinMode(PIN_CHARGE_DET, INPUT);
  analogSetPinAttenuation(PIN_BATT_ADC, ADC_11db);

  if (!loadCalibNVS(imuUpper, imuLower, posture)) {
    doCalibration();
  }

  lastSampleMs = millis();
  lastTelMs = millis();

  dataMutex = xSemaphoreCreateMutex();
  Serial.println("Mutex olusturuldu.");

  BLEDevice::init("Posture_BLE");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ |
                               BLECharacteristic::PROPERTY_NOTIFY |
                               BLECharacteristic::PROPERTY_WRITE |
                               BLECharacteristic::PROPERTY_WRITE_NR);

  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMaxPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("BLE Yayin Baslatildi: Posture_BLE");

  xTaskCreatePinnedToCore(bleTelemetryTask, "BLE_Task", 8192, NULL, 1, NULL, 0);
  Serial.println(">>> SETUP TAMAMLANDI <<<");
}

void loop() {
  handleSerial();

  if (!deviceConnected && oldDeviceConnected) {
    delay(100);
    pServer->startAdvertising();
    Serial.println("[BLE] Yayin yeniden baslatildi.");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  if (doCalibNow) {
    doCalibNow = false;
    bool success = doCalibration();
    if (triggeredFromBLE) {
      triggeredFromBLE = false;
      calibSuccess = success;
      pendingCalibResult = true;
    }
  }

  if (saveConfigNow) {
    saveConfigNow = false;
    saveCalibNVS(imuUpper, imuLower, posture);
    Serial.println("[NVS] Yeni ayarlar kaydedildi.");
  }

  uint32_t now = millis();

  const uint32_t samplePeriodMs = 1000 / SAMPLE_RATE_HZ;

  if ((uint32_t)(now - lastSampleMs) >= samplePeriodMs) {
    float dt = (now - lastSampleMs) / 1000.0f;
    if (dt <= 0)
      dt = 1.0f / SAMPLE_RATE_HZ;
    lastSampleMs = now;

    static float battVoltSmooth = 0.0f;
    float battRaw =
        (analogRead(PIN_BATT_ADC) / 4095.0f) * 3.9f * BATT_DIVIDER_RATIO;
    battVoltSmooth = (battVoltSmooth < 0.1f)
                         ? battRaw
                         : (0.97f * battVoltSmooth + 0.03f * battRaw);

    bool isChargingNow = (digitalRead(PIN_CHARGE_DET) == LOW);

    if (xSemaphoreTake(dataMutex, pdMS_TO_TICKS(10)) == pdTRUE) {
      globalData.timestampMs = now;
      globalData.batteryVoltage = battVoltSmooth;
      globalData.isCharging = isChargingNow;
      xSemaphoreGive(dataMutex);
    }

    MpuSample su, sl;
    if (!imuUpper.readSample(su)) {
      Serial.println("[IMU] Ust sensor okunamadi!");
      delay(10);
      return;
    }
    if (!imuLower.readSample(sl)) {
      Serial.println("[IMU] Alt sensor okunamadi!");
      delay(10);
      return;
    }

    Vec3f accU_b, gyrU_b, accL_b, gyrL_b;
    applyAxisMap(AXIS_UPPER, su.acc_g, accU_b);
    applyAxisMap(AXIS_UPPER, su.gyro_dps, gyrU_b);
    applyAxisMap(AXIS_LOWER, sl.acc_g, accL_b);
    applyAxisMap(AXIS_LOWER, sl.gyro_dps, gyrL_b);

    static bool wasVibrating = false;
    bool isVibratingNow = (digitalRead(PIN_VIB) == HIGH);

    if (isVibratingNow) {
      wasVibrating = true;

    } else {
      float currentAlpha = ORI_ALPHA;
      if (wasVibrating) {

        currentAlpha = 0.0f;
        wasVibrating = false;
        Serial.println("[IMU] Titresim sonrasi acilar hizli eslendi.");
      }
      orientationUpdate(oriUpper, accU_b, gyrU_b, dt, currentAlpha);
      orientationUpdate(oriLower, accL_b, gyrL_b, dt, currentAlpha);
    }

    if (isnan(oriUpper.pitch_deg) || isnan(oriUpper.roll_deg)) {
      oriUpper.pitch_deg = 0;
      oriUpper.roll_deg = 0;
    }
    if (isnan(oriLower.pitch_deg) || isnan(oriLower.roll_deg)) {
      oriLower.pitch_deg = 0;
      oriLower.roll_deg = 0;
    }

    float magLowerG = vecMag(accL_b);
    float magUpperG = vecMag(accU_b);
    float gyroMag = fmaxf(vecMag(gyrL_b), vecMag(gyrU_b));
    activity.update(now, magLowerG, magUpperG, gyroMag, oriUpper.pitch_deg,
                    oriLower.pitch_deg, oriUpper.roll_deg, oriLower.roll_deg,
                    posture);

    float deltaPitch = oriUpper.pitch_deg - oriLower.pitch_deg;
    float deltaRoll = oriUpper.roll_deg - oriLower.roll_deg;

    posture.update(now, oriUpper.pitch_deg, oriLower.pitch_deg, deltaPitch);
    lateralPosture.update(now, oriUpper.roll_deg, oriLower.roll_deg,
                          posture.baselineDeltaRoll, deltaRoll);
    slumpPosture.update(now, deltaPitch, posture.baselineDeltaPitch,
                        oriLower.pitch_deg, posture.baselinePitchLower);

    float deltaPitchErr = deltaPitch - posture.baselineDeltaPitch;
    float deltaRollErr = deltaRoll - posture.baselineDeltaRoll;

    static bool postureGood = true;
    static bool lateralGood = true;
    if (postureGood) {
      if (fabsf(deltaPitchErr) > SLOUCH_THRESHOLD_DEG)
        postureGood = false;
    } else {
      if (fabsf(deltaPitchErr) <
          (SLOUCH_THRESHOLD_DEG - POSTURE_HYSTERESIS_DEG))
        postureGood = true;
    }
    if (lateralGood) {
      if (fabsf(deltaRollErr) > LATERAL_THRESHOLD_DEG)
        lateralGood = false;
    } else {
      if (fabsf(deltaRollErr) <
          (LATERAL_THRESHOLD_DEG - POSTURE_HYSTERESIS_DEG))
        lateralGood = true;
    }

    static bool prevPostureGood = true;
    static bool prevLateralGood = true;
    static bool prevSlumpState = false;
    if (postureGood != prevPostureGood) {
      if (!postureGood)
        Serial.printf(
            "[POSTURE] KOTU -> deltaPitchErr=%.2f derece (esik=%.1f)\n",
            deltaPitchErr, SLOUCH_THRESHOLD_DEG);
      else
        Serial.println("[POSTURE] IYI -> durus duzzeldi");
      prevPostureGood = postureGood;
    }
    if (lateralGood != prevLateralGood) {
      if (!lateralGood)
        Serial.printf(
            "[LATERAL] KOTU -> deltaRollErr=%.2f derece (esik=%.1f)\n",
            deltaRollErr, LATERAL_THRESHOLD_DEG);
      else
        Serial.println("[LATERAL] IYI -> yan egim duzzeldi");
      prevLateralGood = lateralGood;
    }
    if (slumpPosture.state != prevSlumpState) {
      if (slumpPosture.state)
        Serial.printf("[SLUMP] KAYKILMA -> LLA=%.2f pelvis=%.2f derece\n",
                      deltaPitch,
                      fabsf(oriLower.pitch_deg - posture.baselinePitchLower));
      else
        Serial.println("[SLUMP] IYI -> kaykilma duzzeldi");
      prevSlumpState = slumpPosture.state;
    }

    int combinedPostureState = 0;
    if (posture.state == POSTURE_SLOUCH)
      combinedPostureState |= 1;
    if (slumpPosture.state)
      combinedPostureState |= 2;

    static uint32_t vibCycleStart = 0;
    static int prevVibState = 0;
    if (combinedPostureState != prevVibState) {
      vibCycleStart = now;
      prevVibState = combinedPostureState;
    }
    bool isVibOn = false;
    bool isWalkingOrRunning =
        (activity.state == ACT_WALKING || activity.state == ACT_RUNNING);
    if (VIBRATION_ENABLED && combinedPostureState != 0 && !isWalkingOrRunning) {
      uint32_t onMs, offMs;
      if (combinedPostureState == 1) {
        onMs = 500;
        offMs = 1500;
      } else if (combinedPostureState == 2) {
        onMs = 1000;
        offMs = 3000;
      } else {
        onMs = 3000;
        offMs = 1000;
      }
      uint32_t elapsed = (now - vibCycleStart) % (onMs + offMs);
      isVibOn = (elapsed < onMs);
    }
    digitalWrite(PIN_VIB, isVibOn ? HIGH : LOW);

    if (xSemaphoreTake(dataMutex, pdMS_TO_TICKS(10)) == pdTRUE) {
      globalData.timestampMs = now;
      globalData.pitchUpper = oriUpper.pitch_deg;
      globalData.pitchLower = oriLower.pitch_deg;
      globalData.deltaPitch = deltaPitch;
      globalData.rollUpper = oriUpper.roll_deg;
      globalData.rollLower = oriLower.roll_deg;
      globalData.deltaRoll = deltaRoll;
      globalData.postureState = combinedPostureState;
      globalData.lateralState = lateralPosture.state;
      globalData.activityState = activity.state;
      globalData.isVibrating = isVibOn;
      globalData.stepCount = activity.steps;
      globalData.batteryVoltage = battVoltSmooth;
      globalData.isCharging = isChargingNow;
      xSemaphoreGive(dataMutex);
    }

    const uint32_t telPeriodMs = 1000 / TELEMETRY_RATE_HZ;
    if ((uint32_t)(now - lastTelMs) >= telPeriodMs) {
      lastTelMs = now;
      Serial.printf("t=%lu PU=%.2f PL=%.2f dP=%.2f dR=%.2f st=%d lat=%d "
                    "slump=%d act=%d bv=%.2f chg=%d\n",
                    (unsigned long)now, oriUpper.pitch_deg, oriLower.pitch_deg,
                    deltaPitch, deltaRoll, combinedPostureState,
                    (int)lateralPosture.state, (int)slumpPosture.state,
                    (int)activity.state, battVoltSmooth, (int)isChargingNow);
    }
  }
}
