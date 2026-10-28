# Aplikasi Mobile KOPKAR PT Budi Berlian Motor (Koperasi Karyawan)

Aplikasi mobile Flutter modern yang dirancang khusus untuk operasional **Koperasi Karyawan (KOPKAR) PT Budi Berlian Motor** dengan desain antarmuka (UI) clean, rounded, dan modern yang mengacu langsung pada tata kelola koperasi mandiri terintegrasi (Karyawan & Pengurus Admin).

---

## 🌟 Aturan Finansial Koperasi (Business Logic)

Aplikasi ini telah mengimplementasikan logika baku keuangan koperasi karyawan secara otomatis & transparan:

1. **Pemotongan Payroll Bulan Pertama (Karyawan Baru Bergabung):**
   - Misal bergabung tanggal **01 Januari**.
   - Pada slip gaji akhir Januari (bulan ke-1), terpotong otomatis **Rp 125.000**:
     - **Simpanan Pokok:** `Rp 100.000` (hanya dibayar 1x seumur hidup saat awal resmi menjadi anggota).
     - **Simpanan Wajib:** `Rp 25.000` (iuran bulan ke-1).
2. **Pemotongan Payroll Bulan-Bulan Selanjutnya:**
   - Karyawan hanya terpotong rutin **Rp 25.000 / bulan** untuk **Simpanan Wajib**.
3. **Simpanan Sukarela (Tabungan Fleksibel):**
   - Anggota bebas menyetor dan menarik saldo sukarela sewaktu-waktu sesuai saldo yang tersedia.
4. **Pinjaman Anggota & Bunga Flat 1% / Bulan:**
   - Setiap karyawan yang mengajukan pinjaman dikenakan **bunga flat 1% per bulan** dari pokok pinjaman yang diajukan (pilihan tenor 1 s/d 12 bulan).
   - **Formula Cicilan Bulanan:**
     $$\text{Cicilan Bulanan} = \left(\frac{\text{Pokok Pinjaman}}{\text{Tenor Bulan}}\right) + \mathbf{(1\% \times \text{Pokok Pinjaman})}$$
   - *Contoh:* Pinjam Rp 5.000.000 tenor 5 bulan:
     - Pokok per bulan: $\text{Rp 1.000.000}$
     - Bunga 1% per bulan: $\text{Rp 50.000}$
     - Total angsuran payroll: **Rp 1.050.000 / bulan**.
5. **Transparansi Bagi Hasil Bunga 1% (SHU ke Seluruh Anggota Aktif):**
   - Seluruh bunga 1% yang dibayarkan oleh peminjam **TIDAK** diambil oleh pengurus atau perusahaan.
   - Bunga 1% tersebut dikumpulkan tiap bulan dan **DIBAGI RATA 100%** ke **seluruh karyawan yang berstatus Anggota Aktif** (termasuk yang tidak meminjam):
     $$\text{Bagi Hasil per Anggota} = \frac{\text{Total Bunga 1\% Terkumpul Bulan Ini}}{\text{Jumlah Seluruh Anggota Aktif}}$$
   - Saldo ini terakumulasi otomatis ke dalam **Saldo Bagi Hasil Bunga 1% (SHU)** anggota.
6. **Jaminan 100% Pengembalian Simpanan saat Karyawan Resign:**
   - Saat karyawan mengundurkan diri (resign), seluruh hak dana **WAJIB 100% DIKEMBALIKAN** ke rekening pribadi karyawan dengan formula:
     $$\text{Total Refund} = (\text{Simpanan Pokok}) + (\text{Total Simpanan Wajib}) + (\text{Simpanan Sukarela}) + \mathbf{(Saldo\ Bagi\ Hasil\ Bunga\ 1\%)} - (\text{Sisa\ Pinjaman})$$

---

## 📱 Modul & Fitur Utama Aplikasi

### A. Modul Karyawan (Member Area)
1. **Onboarding & Pendaftaran Karyawan Baru (`onboarding_screen.dart`, `login_screen.dart`):**
   - Registrasi karyawan dengan NIK, nama lengkap, departemen, dan rekening bank pribadi.
   - Verifikasi PIN 6-Digit & proteksi keamanan sesi.
2. **Dashboard Anggota Interaktif (`user_dashboard_screen.dart`):**
   - Kartu digital anggota: NIK, Masa Keanggotaan, Total Saldo Akumulasi.
   - Grid Menu: Potongan Gaji, Buku Simpanan, Pengajuan Pinjaman, Setor/Tarik Sukarela, Info SHU 1%, Klaim Resign, dan Download E-Statement.
3. **Buku Simpanan & Download PDF (`savings_detail_screen.dart`, `pdf_generator.dart`):**
   - Transkrip mutasi setoran dan penarikan simpanan lengkap.
   - Cetak langsung **E-Statement Resmi PDF** saldo simpanan dan bagi hasil.
4. **Pengajuan Pinjaman & Live Calculator (`loan_screen.dart`):**
   - Simulasi pinjaman interaktif dengan slider plafon dan tenor.
   - Kotak rincian angsuran pokok + bunga 1% dan simulasi transparansi bagi hasil ke anggota aktif.
   - Peringatan pintar jika masih memiliki pinjaman aktif atau antrean persetujuan.
5. **Klaim Pengunduran Diri / Resign (`resignation_screen.dart`):**
   - Kalkulator otomatis hak pencairan dana 100% (Pokok + Wajib + Sukarela + Bagi Hasil 1% - Sisa Pinjaman).

### B. Modul Pengurus & Administrator (`admin_dashboard_screen.dart`, `admin_service_screens.dart`)
1. **Halaman Layanan Pengurus Mandiri:**
   - **Eksekusi Payroll Bulanan:** Auto-debit simpanan pokok (Rp 100rb bulan ke-1), simpanan wajib (Rp 25rb rutin), angsuran pinjaman, serta pendistribusian bunga 1% ke anggota aktif secara otomatis.
   - **Persetujuan Pinjaman:** Verifikasi kelayakan, upload bukti transfer pencairan bank, dan aktivasi pinjaman.
   - **Persetujuan Setor & Pencairan Sukarela:** Validasi bukti transfer setoran dan persetujuan penarikan sukarela.
   - **Klaim Resign & Pencairan Dana:** Eksekusi transfer hak refund dana 100% ke rekening karyawan.
   - **Rekap Payroll Perusahaan:** Laporan potongan gaji karyawan per periode bulan/tahun.
   - **Pelunasan Dipercepat:** Pembayaran lunas di awal dengan pembagian sisa bunga 1% ke anggota aktif.
   - **Verifikasi Akun Baru & Reset PIN:** Approval pendaftaran karyawan baru dan pemulihan PIN terkunci.
2. **Pengaturan Sistem & Perlindungan Data:**
   - Pengaturan nomor rekening resmi bank koperasi KOPKAR BBM.
   - **Zona Bahaya (Danger Zone):** Fitur pengosongan/reset data anggota yang dilindungi verifikasi PIN Keamanan / Password Admin.

---

## 🔒 Standar Keamanan & Proteksi Enterprise

Aplikasi KOPKAR PT BBM dilengkapi arsitektur proteksi setara aplikasi perbankan (Bank-Grade Security):
* **Dual-Token Auth (Access Token 15 Menit + Refresh Token 30 Hari)** dengan mekanisme Refresh Token Rotation (RTR).
* **Anti-Theft Replay Detection:** Otomatis memblokir sesi jika token terdeteksi dicuri atau digunakan berulang.
* **Hardware MAC Address Binding (AES-256 GCM):** Token terenkripsi dengan identitas fisik perangkat.
* **FLAG_SECURE & Inactivity Auto-Lock (3 Menit):** Mencegah screenshot liar dan auto-lock saat aplikasi ditinggalkan.
* **Input Sanitization Engine:** Proteksi injeksi XSS, SQLi, dan validasi ketat.

---

## 🚀 Cara Menjalankan Project Flutter

```bash
# 1. Buka direktori project
cd /Users/fahmi/.gemini/antigravity/scratch/kopkar_app

# 2. Ambil dependensi Flutter
flutter pub get

# 3. Jalankan Pengujian Unit & Security (14 Test Suites)
flutter test

# 4. Jalankan Aplikasi
flutter run
```
