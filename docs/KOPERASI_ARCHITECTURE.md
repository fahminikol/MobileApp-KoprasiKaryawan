# Panduan Lengkap Arsitektur & Sistem Koperasi Karyawan (KOPKAR)

Dokumen ini disusun untuk menjelaskan secara menyeluruh cara kerja sistem Koperasi Karyawan, arsitektur database, pembagian peran **Admin** vs **User (Anggota)**, serta aturan finansial sesuai regulasi Koperasi di Indonesia.

---

## 1. Pemahaman Dasar Koperasi Karyawan untuk Pemula

Koperasi Karyawan (KOPKAR) adalah badan usaha yang didirikan di dalam suatu perusahaan dari karyawan, oleh karyawan, dan untuk kesejahteraan karyawan.

### Jenis-Jenis Simpanan Utama:
1. **Simpanan Pokok (Rp 100.000)**:
   - **Hanya dibayar 1x seumur hidup** saat karyawan pertama kali mendaftar/bergabung menjadi anggota.
   - Dipotong pada slip gaji akhir bulan pertama bergabung.
   - **Sifat:** Tidak dapat ditarik selama masih menjadi karyawan/anggota aktif. **Wajib dikembalikan 100% saat karyawan resign.**
2. **Simpanan Wajib (Rp 25.000 / bulan)**:
   - Iuran rutin yang dipotong otomatis setiap bulan dari slip gaji karyawan melalui integrasi payroll HRD/Finance.
   - Terus terakumulasi setiap bulan selama aktif bekerja.
   - **Sifat:** Tidak dapat ditarik selama masih aktif. **Wajib dikembalikan 100% seluruh total yang terkumpul saat karyawan resign.**
3. **Simpanan Sukarela (Fleksibel)**:
   - Tabungan tambahan yang bebas disetor (top up) nominal berapa saja dan **bisa ditarik sewaktu-waktu**.
   - Mendapatkan porsi bagi hasil jasa modal tahunan (SHU).
4. **Pinjaman Karyawan**:
   - Fasilitas pinjaman berbunga sangat rendah (misal: 6% flat per tahun / 0.5% per bulan) dengan sistem potong gaji bulanan.
5. **SHU (Sisa Hasil Usaha)**:
   - Keuntungan bersih koperasi selama 1 tahun buku yang dibagikan kembali kepada seluruh anggota pada saat Rapat Anggota Tahunan (RAT).

---

## 2. Logika Finansial: Bergabung, Rutin, & Resign

### Skenario A: Karyawan Baru Bergabung (Contoh: Masuk 01 Januari)
- **Akhir Januari (Bulan ke-1):** Karyawan terkena potongan payroll sebesar **Rp 125.000**:
  - `Simpanan Pokok` = Rp 100.000 (1x pertama kali)
  - `Simpanan Wajib` = Rp 25.000 (Bulan ke-1)
- **Akhir Februari dan bulan-bulan berikutnya (Bulan ke-2 dst):**
  - Hanya terkena potongan `Simpanan Wajib` = **Rp 25.000 / bulan**.

### Skenario B: Karyawan Resign (Keluar dari Perusahaan)
Saat karyawan resign, status keanggotaannya berakhir dan koperasi **WAJIB** mengembalikan seluruh hak simpanannya dengan rumus:

$$\text{Net Refund} = (\text{Simpanan Pokok 1x}) + (\text{Total Simpanan Wajib Terkumpul}) + (\text{Simpanan Sukarela}) - (\text{Sisa Pinjaman})$$

**Contoh Kasus Resign:**
- Agus bekerja selama 14 bulan:
  - 1x Simpanan Pokok = Rp 100.000
  - Simpanan Wajib 14 bulan x Rp 25.000 = Rp 350.000
  - Simpanan Sukarela = Rp 750.000
  - Sisa Pinjaman = Rp 0
  - **Total Hak Pengembalian Bersih (Net Refund) = Rp 1.200.000 (Wajib ditransfer ke rekening bank Agus).**

---

## 3. Pembagian Peran: Admin (Pengurus) vs User (Anggota)

| Fitur / Modul | Anggota / Karyawan (Mobile App) | Pengurus / Admin Koperasi (Dashboard) |
|---|---|---|
| **Akses Dashboard** | Melihat saldo simpanan pribadi, masa keanggotaan, & slip potongan. | Melihat ringkasan seluruh kas koperasi, total simpanan, dan jumlah anggota. |
| **Potongan Gaji** | Melihat riwayat mutasi bulanan & notifikasi potongan gaji sukses. | Mengeksekusi **Batch Auto-Debit Payroll** bulanan dan export file laporan ke HRD. |
| **Pinjaman** | Simulasi angsuran & mengajukan pinjaman dengan tenor pilihan. | Meninjau kelayakan (cek sisa masa kerja & plafon gaji), lalu **Approve / Reject**. |
| **Simpanan Sukarela**| Setor mandiri (top up) atau tarik tunai sewaktu-waktu. | Validasi mutasi kas masuk/keluar tabungan sukarela. |
| **Proses Resign** | Mengajukan formulir klaim resign & memasukkan nomor rekening penerima. | Memverifikasi kalkulasi hak refund, melakukan transfer dana, lalu menonaktifkan akun. |
| **Laporan** | Download E-Statement / Buku Tabungan PDF pribadi. | Cetak Laporan Keuangan, Neraca Kas, Laba Rugi, dan Kalkulasi SHU Tahunan. |

---

## 4. Rekomendasi Arsitektur Database & Backend

Untuk aplikasi mobile Flutter Koperasi Karyawan, kami sangat merekomendasikan **Supabase (PostgreSQL)** atau **Laravel / Node.js REST API + PostgreSQL**:

1. **Kenapa PostgreSQL / Supabase?**
   - Transaksi finansial koperasi membutuhkan standar **ACID (Atomicity, Consistency, Isolation, Durability)** agar mutasi debit/kredit tidak pernah selisih 1 rupiah pun.
   - Memiliki fitur **Row Level Security (RLS)**: Karyawan hanya bisa melihat data simpanannya sendiri, sedangkan Admin bisa melihat seluruh data.
   - Built-in Authentication (Email/Password, NIK, SSO Google).
   - Real-time updates saat ada potongan gaji atau status approval pinjaman berubah.

2. **File Skema Database:**
   - File skema lengkap siap pakai telah disediakan di:
     `docs/database_schema.sql`

---

## 5. Struktur Folder Project Flutter (`kopkar_app`)

```text
kopkar_app/
├── lib/
│   ├── main.dart                      # Inisialisasi aplikasi & theme
│   ├── theme/
│   │   └── app_theme.dart             # Palette warna (Indigo, Soft Grey, Pastel Badges)
│   ├── models/
│   │   ├── member_model.dart          # Data model anggota & kalkulator masa kerja
│   │   ├── transaction_model.dart     # Data model mutasi simpanan & potongan
│   │   ├── loan_model.dart            # Data model pinjaman & rumus bunga flat
│   │   └── resignation_model.dart     # Data model klaim pengembalian dana resign
│   ├── services/
│   │   └── coop_service.dart          # Mesin logika bisnis & state management
│   ├── widgets/
│   │   ├── stat_box.dart              # Card metrik 2x2 (Simpanan Pokok, Wajib, Sukarela)
│   │   └── bottom_nav_bar.dart        # Navigasi elegan 5 tab
│   └── screens/
│       ├── onboarding_screen.dart     # Layar awal (Matching Screen 1)
│       ├── user_dashboard_screen.dart # Dashboard Anggota (Matching Screen 2)
│       ├── savings_detail_screen.dart # Detail Simpanan & PDF (Matching Screen 3)
│       ├── loan_screen.dart           # Simulasi & Pengajuan Pinjaman
│       ├── resignation_screen.dart    # Kalkulator & Formulir Klaim Resign
│       ├── admin_dashboard_screen.dart# Panel Pengurus: Batch Payroll & Approval
│       └── main_navigation_screen.dart# Tab Controller & Role Switcher
├── docs/
│   ├── database_schema.sql            # Skema lengkap PostgreSQL/Supabase
│   └── KOPERASI_ARCHITECTURE.md       # Panduan konsep & aturan bisnis
└── pubspec.yaml                       # Konfigurasi dependensi Flutter
```
