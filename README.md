# logbook_app_024 - Panduan Instalasi

Dokumen ini berisi langkah instalasi dan menjalankan project Flutter `logbook_app_024` dari awal.

## 1. Prasyarat

Pastikan perangkat development sudah memiliki:

- Flutter SDK (disarankan channel stable)
- Dart SDK (ikut terpasang bersama Flutter)
- Android Studio atau VS Code + Flutter extension
- Android SDK + emulator, atau perangkat Android fisik
- Git

Cek instalasi Flutter:

```bash
flutter --version
flutter doctor
```

Pastikan hasil `flutter doctor` tidak ada error kritis.

## 2. Clone Repository

```bash
git clone <url-repository-anda>
cd logbook_app_024
```

Jika project sudah ada di lokal, cukup masuk ke folder project:

```bash
cd logbook_app_024
```

## 3. Install Dependency

Jalankan:

```bash
flutter pub get
```

Project ini menggunakan package utama seperti:

- `camera`
- `permission_handler`
- `image`
- `image_picker`
- `path_provider`

## 4. Konfigurasi Environment (Jika Diperlukan)

Project memuat `.env` sebagai asset. Jika aplikasi membutuhkan variabel environment, buat file `.env` di root project sesuai kebutuhan backend/API.

Contoh sederhana:

```env
API_BASE_URL=https://example.com
```

## 5. Menjalankan Aplikasi

### 5.1 Cek device yang tersedia

```bash
flutter devices
```

### 5.2 Jalankan aplikasi

```bash
flutter run
```

Atau jalankan ke device tertentu:

```bash
flutter run -d <device_id>
```

## 6. Build APK (Opsional)

Untuk build release Android:

```bash
flutter build apk --release
```

Hasil build ada di folder:

`build/app/outputs/flutter-apk/`

## 7. Menjalankan Test (Opsional)

```bash
flutter test
```

## 8. Troubleshooting Umum

### A. Dependency gagal terpasang

```bash
flutter clean
flutter pub get
```

### B. Kamera tidak tampil

- Pastikan izin kamera di device sudah diizinkan.
- Coba uninstall lalu install ulang app.
- Pastikan tidak ada aplikasi lain yang sedang mengunci kamera.

### C. Build Android gagal

- Jalankan `flutter doctor` dan selesaikan error SDK/License.
- Sinkronkan gradle di Android Studio jika diperlukan.

## 9. Catatan Penggunaan Fitur Vision

- Halaman Vision menggunakan preview kamera + overlay.
- Pengguna dapat mengambil foto dan membuka editor manipulasi citra.
- Tersedia opsi upload gambar dari galeri untuk diproses di editor.

---

Jika kamu ingin, README ini bisa aku lanjutkan ke versi "untuk user non-teknis" (panduan pakai aplikasi langkah demi langkah), terpisah dari panduan instalasi developer.
