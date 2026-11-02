const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { OpenAI } = require("openai");

admin.initializeApp();

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

exports.generateDailyReport = onCall(
  {
    secrets: [OPENAI_API_KEY],
    timeoutSeconds: 60,
    region: "europe-west1",
  },
  async (request) => {

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş yapmanız gerekiyor.");
    }

    const { date, userId, payload } = request.data;

    if (!date || !userId || !payload) {
      throw new HttpsError("invalid-argument", "Eksik parametre: date, userId veya payload.");
    }

    if (request.auth.uid !== userId) {
      throw new HttpsError("permission-denied", "Başka bir kullanıcı adına rapor oluşturamazsınız.");
    }

    const db = admin.firestore();
    const reportRef = db.collection("users").doc(userId).collection("my_reports").doc(date);

    const existing = await reportRef.get();
    if (existing.exists) {
      return { content: existing.data().content };
    }

    const prompt = buildPrompt(payload);

    const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });

    let reportContent;
    try {
      const completion = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "Sen bir kişisel sağlık koçusun. Kullanıcının duruş ve aktivite verilerini analiz ederek " +
              "kısa, motive edici ve pratik önerileri olan günlük bir rapor yazıyorsun. " +
              "Yanıt Türkçe olmalı. Maksimum 300 kelime. Başlıklar kullanma, akıcı paragraflar yaz. " +
              "Kullanıcıyı isim ile değil 'bugün' veya doğrudan 'sen' diye hitap et.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        max_tokens: 600,
        temperature: 0.75,
      });

      reportContent = completion.choices[0]?.message?.content?.trim() || "";
    } catch (err) {
      console.error("OpenAI API hatası:", err);
      throw new HttpsError("internal", "AI raporu oluşturulamadı: " + err.message);
    }

    if (!reportContent) {
      throw new HttpsError("internal", "AI boş yanıt döndürdü.");
    }

    await reportRef.set({
      date: date,
      content: reportContent,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Rapor oluşturuldu: userId=${userId}, date=${date}`);

    return { content: reportContent };
  }
);

function buildPrompt(payload) {
  const g = payload.goals || {};
  const u = payload.userProfile || {};
  const eod = payload.eodReviews || [];
  const blocks = payload.activityBlocks || [];
  const corrections = payload.correctionTimes_secs || [];
  const device = payload.deviceSettings || {};

  const workDayNames = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
  const workDaysStr = (u.workDays || [])
    .map((d) => workDayNames[d - 1] || d)
    .join(", ");

  const workTypeMap = {
    office: "Masa başı (ofis)",
    standing: "Ayakta çalışma",
    mixed: "Karma (ofis + ayakta)",
  };

  const eodSummary = eod
    .map(
      (r) =>
        `${r.date}: Enerji ${r.energyLevel}/5, Ağrı ${r.painLevel}/5${
          r.notes ? `, Not: "${r.notes}"` : ""
        }`
    )
    .join("\n");

  const blockSummary = blocks
    .slice(0, 10)
    .map(
      (b) =>
        `${b.type === "sitting" ? "Oturma" : "Ayakta"} ${b.duration_secs}sn` +
        `, Ort. eğim: ${b.avgPostureAngle_deg}°` +
        (b.type === "standing" ? `, ${b.steps} adım` : "")
    )
    .join("\n");

  let correctionSummary;
  if (corrections.length > 0) {
    const avg = Math.round(corrections.reduce((a, b) => a + b, 0) / corrections.length);
    correctionSummary = `Ortalama düzelme süresi: ${avg} saniye (${corrections.length} uyarı sonrası düzelme ölçüldü).`;
  } else {

    const uprightPct = g.uprightCompletion_pct ?? 0;
    if (uprightPct >= 70) {
      correctionSummary = "Düzelme ölçümü yapılmadı — dik duruş hedefi yüksek oranda tamamlandığından bu büyük ihtimalle gün boyu iyi duruş korunduğu anlamına gelir.";
    } else if (uprightPct >= 30) {
      correctionSummary = `Düzelme ölçümü yapılmadı — dik duruş hedefinin yalnızca %${uprightPct}'i tamamlandı. Kötü duruş uyarısı gelmeden önce düzeltme yapılmış olabilir ya da duruş düzeltme gecikmesi ayarı yeterince değerlendirilmedi.`;
    } else {
      correctionSummary = `Düzelme ölçümü yapılmadı — dik duruş hedefinin yalnızca %${uprightPct}'i tamamlandı. Bu düşük oran, gün boyunca duruş kalitesinin zayıf olduğuna işaret ediyor olabilir.`;
    }
  }

  return `
## Kullanıcı Profili
- Boy: ${u.heightCm} cm, Kilo: ${u.weightKg} kg
- Sağlık sorunu: ${u.painDescription || "Belirtilmemiş"}
- Çalışma biçimi: ${workTypeMap[u.workType] || u.workType}
- Çalışma günleri: ${workDaysStr}

## ${payload.reportDate} Tarihli Gün Hedefleri ve Tamamlanma
- Dik duruş: ${g.uprightAchieved_mins} / ${g.uprightTarget_mins} dk (%${g.uprightCompletion_pct})
- Adım: ${g.stepsAchieved} / ${g.stepsTarget} (%${g.stepsCompletion_pct})
- Ayakta durma: ${g.standingAchieved_mins} / ${g.standingTarget_mins} dk (%${g.standingCompletion_pct})

## Son 3 Gün Değerlendirmeleri
${eodSummary || "Değerlendirme yok."}

## Aktivite Blokları (Kesintisiz Oturma/Ayakta Durma)
${blockSummary || "Yeterli veri yok."}

## Duruş Düzeltme Süresi
${correctionSummary}

## Cihaz Ayarları
- Uyarı eşiği: ${device.uprightThresholdDeg}° eğim
- Titreşim gecikmesi: ${device.vibrationDelaySecs} saniye

Yukarıdaki verilere dayanarak kullanıcıya kısa, samimi ve motive edici bir günlük rapor yaz.
`;
}

exports.onNotificationAdded = onDocumentCreated(
  { document: "users/{userId}/notifications/{notificationId}", region: "europe-west1" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("Veri yok");
      return;
    }

    const notification = snapshot.data();
    const userId = event.params.userId;

    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (!userDoc.exists) return;

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      console.log(`FCM token bulunamadı: ${userId}`);
      return;
    }

    const payload = {
      notification: {
        title: notification.title || "Yeni Bildirim",
        body: notification.message || ""
      },
      token: fcmToken
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log("FCM gönderildi:", response);
    } catch (error) {
      console.error("FCM hatası:", error);
    }
  }
);
