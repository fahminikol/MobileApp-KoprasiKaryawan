# Aplikasi Mobile KOPKAR Sejahtera (Koperasi Karyawan)

Aplikasi mobile Flutter modern yang dirancang khusus untuk operasional **Koperasi Karyawan (KOPKAR)** perusahaan dengan desain antarmuka (UI) clean, rounded, dan modern yang mengacu langsung pada referensi desain UI (Onboarding Screen, Dashboard Anggota, dan Detail Simpanan/Transkrip).

---

## 🌟 Aturan Finansial Koperasi (Business Logic)

Aplikasi ini telah mengimplementasikan logika baku koperasi karyawan secara otomatis:

1. **Pemotongan Payroll Bulan Pertama (Karyawan Baru Gabung):**
   - Misal bergabung tanggal **01 Januari**.
   - Pada slip gaji akhir Januari (bulan ke-1), terpotong otomatis **Rp 125.000**:
     - **Simpanan Pokok:** `Rp 100.000` (hanya dibayar 1x seumur hidup saat awal menjadi anggota).
     - **Simpanan Wajib:** `Rp 25.000` (iuran bulan ke-1).
2. **Pemotongan Payroll Bulan-Bulan Selanjutnya:**
   - Karyawan hanya terpotong rutin **Rp 25.000 / bulan** untuk **Simpanan Wajib**.
3. **Simpanan Sukarela (Tabungan Fleksibel):**
   - Anggota bebas menyetor dan menarik saldo sukarela sewaktu-waktu.
4. **Jaminan Pengembalian Simpanan saat Karyawan Resign:**
   - Saat karyawan mengundurkan diri (resign), seluruh hak simpanan **WAJIB 100% DIKEMBALIKAN** ke rekening pribadi karyawan dengan formula:
     $$\text{Total Refund} = (\text{Simpanan Pokok Rp 100.000}) + (\text{Total Simpanan Wajib Terkumpul}) + (\text{Simpanan Sukarela}) - (\text{Sisa Pinjaman})$$

---

## 📱 Modul & Tampilan UI Sesuai Referensi

1. **Screen 1: Onboarding Screen (`onboarding_screen.dart`)**
   - Gradient biru cobalt/indigo khas aplikasi modern.
   - Mockup smartphone 3D dan kartu informasi transparan.
   - Bottom sheet melengkung dengan indikator 3 titik dan tombol *"Mulai Sekarang"*.
2. **Screen 2: Dashboard Anggota (`user_dashboard_screen.dart`)**
   - Greeting personal: *"Selamat datang di, KOPKAR PT Sejahtera"*.
   - Kartu Anggota Biru Gradasi: Menampilkan NIK, Nama Karyawan, Departemen, Total Saldo, dan Badge masa aktif keanggotaan.
   - Grid 8 Menu Pastel (4 kolom x 2 baris): Potongan Gaji, Simpanan, Pinjaman, Sukarela, Resign, Kantin Mart, E-Statement, dan Lainnya.
   - Kartu Notifikasi Payroll dengan aksen bar hijau sukses.
3. **Screen 3: Detail Simpanan & Transkripsi (`savings_detail_screen.dart`)**
   - Dropdown selektor periode / tahun buku berjalan.
   - Grid 2x2 Metric Cards: Simpanan Pokok, Simpanan Wajib, Simpanan Sukarela, dan Total Tabungan.
   - Tombol utama *"Download E-Statement PDF"* & riwayat mutasi debit/kredit.
4. **Screen 4: Klaim Resign & Live Calculator (`resignation_screen.dart`)**
   - Kalkulator real-time rincian hak pengembalian dana 100%.
   - Formulir rekening bank tujuan transfer refund.
5. **Screen 5: Panel Pengurus / Admin (`admin_dashboard_screen.dart`)**
   - Tombol 1-klik eksekusi **Batch Auto-Debit Payroll** bulanan (otomatis deteksi bulan ke-1 Rp 125k vs bulan ke-2 dst Rp 25k).
   - Approval klaim resign dan verifikasi transfer dana pengembalian.
   - Approval pengajuan pinjaman karyawan.
   - Penggantian akun simulasi anggota.

---

## 🗄️ Database & Arsitektur Backend

File skema database SQL siap pakai telah disediakan di:
`docs/database_schema.sql`

- **Tabel Utama:** `users`, `members`, `savings_types`, `member_savings_balances`, `savings_transactions`, `payroll_deduction_batches`, `loans`, `loan_installments`, `resignation_claims`, `shu_fiscal_years`.
- **Rekomendasi Backend:** Supabase (PostgreSQL) atau REST API Laravel/Express.js dengan PostgreSQL untuk integritas ACID mutasi keuangan.

---

## 🚀 Cara Menjalankan Project Flutter

```bash
# 1. Buka direktori project
cd /Users/fahmi/.gemini/antigravity/scratch/kopkar_app

# 2. Ambil dependensi Flutter
flutter pub get

# 3. Jalankan di Emulator / Perangkat
flutter run
```
