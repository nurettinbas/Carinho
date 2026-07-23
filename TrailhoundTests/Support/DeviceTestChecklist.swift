import Foundation

/// Manual device test checklist — run on a real phone after each release candidate.
enum DeviceTestChecklist {
    static let items = [
        "30+ dk gerçek sürüş: km ve süre akıyor",
        "Arka plana at, 5 dk bekle: kayıt devam ediyor",
        "Eşleşmiş araca Bluetooth ile bağlanınca otomatik başla (müzik çalmadan)",
        "Araçtan ayrılınca / Bluetooth kesilince otomatik dur",
        "Uygulamayı öldür → aç → orphan banner / recovery",
        "Detay haritada rota gerçekçi (denizden geçmiyor)"
    ]
}
