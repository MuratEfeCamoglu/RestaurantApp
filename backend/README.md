# Limon & Zeytin — Backend

Adisyon uygulamasının REST API'si. Dart (`shelf` + `shelf_router`) ile
yazılmıştır ve verileri yanındaki `addisyon.db` SQLite dosyasında saklar.

## Çalıştırma

```bash
cd backend
dart pub get
dart run bin/server.dart
```

Sunucu varsayılan olarak `8080` portunda ayağa kalkar ve şunu yazdırır:

```
Limon & Zeytin backend çalışıyor:
  Yerel:  http://localhost:8080
  Ağda:   http://192.168.x.x:8080  (aynı Wi-Fi'daki cihazlar için)
```

Telefon/tablet gibi başka bir cihazdan bağlanacaksanız (Flutter uygulaması
fiziksel bir cihazda çalışıyorsa) "Ağda" yazan adresi kullanın — bilgisayar
ve telefon aynı Wi-Fi ağında olmalı. `flutter run` sırasında bu adresi
`--dart-define=API_BASE_URL=http://192.168.x.x:8080` ile Flutter tarafına
verebilirsiniz (bkz. `addisyonapp/lib/api_client.dart`).

Port değiştirmek isterseniz: `PORT=9090 dart run bin/server.dart`.

## Veritabanı

İlk çalıştırmada `addisyon.db` otomatik oluşturulur ve 4 alan (Salon, Teras,
Bar, Balkon) altında 40 masa + menü ile tohumlanır. Dosyayı silip yeniden
başlatırsanız veriler sıfırdan tohumlanır.

Windows için gereken `sqlite3.dll` bu klasörde hazır bulunuyor
(`sqlite3.org`'dan indirilen resmi derleme). Linux/macOS'ta sistemde kurulu
SQLite kütüphanesini kullanır (`apt install libsqlite3-0` / macOS'ta zaten
mevcuttur).

## API özeti

| Metod & yol | Açıklama |
|---|---|
| `GET /api/bootstrap` | areas + tables + menu + categories tek seferde |
| `GET/POST /api/areas` | alanları listele / yeni alan ekle |
| `GET/POST /api/tables` | masaları listele / yeni masa ekle |
| `PUT /api/tables/:id` | masa adı/alanını düzenle |
| `DELETE /api/tables/:id` | masayı sil (sadece boşsa) |
| `POST /api/tables/:id/open` | masayı aç (misafir sayısıyla) |
| `POST /api/tables/:id/request-bill` | hesabı iste |
| `POST /api/tables/:id/settle` | ödemeyi al, masayı sıfırla (yalnızca hesap istenmişse, aksi halde 409) |
| `GET /api/tables/:id/bill` | masanın güncel hesabı |
| `GET /api/menu` | menü listesi |
| `POST /api/orders` | mutfağa sipariş gönder |
| `GET /api/kitchen` | mutfakta hazırlanan siparişler (masa bazında) |
| `POST /api/orders/:id/served` | siparişi hazır/servis edildi işaretle |

Hatalar `{"error": "..."}` gövdesiyle uygun HTTP durum koduyla döner.
