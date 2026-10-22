-- ========================================================================
-- SISTEM DATABASE KOPERASI KARYAWAN (KOPKAR) PT BUDI BERLIAN MOTOR
-- Database Engine: PostgreSQL 14+ / Supabase Cloud Compatible
-- Standar Akuntansi Koperasi Indonesia, Bunga 1% & Potongan Payroll HRD
-- ========================================================================

-- 0. TABEL SINKRONISASI REAL-TIME CLOUD (UNTUK SINKRONISASI INSTAN ANTAR-HP)
CREATE TABLE IF NOT EXISTS kopkar_cloud_store (
    store_key VARCHAR(50) PRIMARY KEY,
    payload JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 1. TABEL PENGGUNA & PENGURUS ADMIN (Sistem Keamanan & RBAC)
CREATE TABLE IF NOT EXISTS admins (
    id VARCHAR(60) PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(30) NOT NULL CHECK (role IN ('superAdmin', 'ketuaKoperasi', 'bendahara', 'sekretaris')),
    phone VARCHAR(30) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. TABEL DATA MASTER ANGGOTA KARYAWAN (Lengkap dengan PIN 6-Digit & Bagi Hasil 1%)
CREATE TABLE IF NOT EXISTS members (
    id VARCHAR(60) PRIMARY KEY,
    nik VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    department VARCHAR(100) NOT NULL,
    email VARCHAR(150),
    phone VARCHAR(30) NOT NULL,
    join_date DATE NOT NULL,
    bank_name VARCHAR(50) NOT NULL,
    bank_account_number VARCHAR(50) NOT NULL,
    bank_account_holder VARCHAR(150) NOT NULL,
    is_bank_verified BOOLEAN DEFAULT TRUE,
    security_pin VARCHAR(6) NOT NULL DEFAULT '123456',
    is_biometric_enabled BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pendingResign', 'resigned')),
    simpanan_pokok NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    simpanan_wajib NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    simpanan_sukarela NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    saldo_bagi_hasil_bunga NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    active_loan_balance NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_members_nik ON members(nik);
CREATE INDEX IF NOT EXISTS idx_members_status ON members(status);

-- 3. TABEL JENIS SIMPANAN KOPERASI (Termasuk Bagi Hasil Bunga 1%)
CREATE TABLE IF NOT EXISTS savings_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    default_amount NUMERIC(15, 2) DEFAULT 0,
    is_refundable_on_resign BOOLEAN DEFAULT TRUE,
    frequency VARCHAR(20) NOT NULL CHECK (frequency IN ('once', 'monthly', 'flexible'))
);

INSERT INTO savings_types (code, name, description, default_amount, is_refundable_on_resign, frequency) VALUES
('POKOK', 'Simpanan Pokok', 'Simpanan awal 1x saat menjadi anggota (Gajian Pertama Rp 100.000)', 100000.00, TRUE, 'once'),
('WAJIB', 'Simpanan Wajib', 'Simpanan rutin bulanan melalui potongan gaji HRD (Rp 25.000/bulan)', 25000.00, TRUE, 'monthly'),
('SUKARELA', 'Simpanan Sukarela', 'Simpanan tambahan yang diverifikasi Admin & bebas ditarik dengan PIN', 0.00, TRUE, 'flexible'),
('BAGI_HASIL_BUNGA', 'Bagi Hasil Bunga Pinjaman 1%', 'Pembagian rata bunga pinjaman 1% per bulan kepada seluruh anggota aktif', 0.00, TRUE, 'monthly')
ON CONFLICT (code) DO NOTHING;

-- 4. TABEL BUKU BESAR MUTASI TRANSAKSI (LEDGER / TRANSACTIONS)
CREATE TABLE IF NOT EXISTS savings_transactions (
    id VARCHAR(80) PRIMARY KEY,
    member_id VARCHAR(60) NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    member_name VARCHAR(150) NOT NULL,
    transaction_type VARCHAR(40) NOT NULL CHECK (transaction_type IN (
        'simpananPokok',
        'simpananWajib',
        'simpananSukarela',
        'penarikanSukarela',
        'pencairanPinjaman',
        'angsuranPinjaman',
        'pelunasanPinjaman',
        'bagiHasilBunga',
        'refundResign'
    )),
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'success' CHECK (status IN ('pending', 'success', 'failed')),
    description TEXT NOT NULL,
    period_month INT CHECK (period_month BETWEEN 1 AND 12),
    period_year INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_trans_member_date ON savings_transactions(member_id, created_at DESC);

-- 5. TABEL PINJAMAN KARYAWAN (LOANS - Bunga 1%/Bulan, Maksimal 12 Bulan)
CREATE TABLE IF NOT EXISTS loans (
    id VARCHAR(80) PRIMARY KEY,
    member_id VARCHAR(60) NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    member_name VARCHAR(150) NOT NULL,
    principal_amount NUMERIC(15, 2) NOT NULL CHECK (principal_amount > 0),
    tenor_months INT NOT NULL CHECK (tenor_months BETWEEN 1 AND 12),
    paid_installments INT NOT NULL DEFAULT 0,
    interest_rate_annual NUMERIC(5, 2) NOT NULL DEFAULT 12.00,
    purpose TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'active', 'settled')),
    approved_by_admin VARCHAR(150),
    rejection_reason TEXT,
    remaining_balance NUMERIC(15, 2) NOT NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. TABEL KLAIM RESIGN & PENGEMBALIAN DANA 100% (Termasuk Bagi Hasil Bunga 1%)
CREATE TABLE IF NOT EXISTS resignation_claims (
    id VARCHAR(80) PRIMARY KEY,
    member_id VARCHAR(60) NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    member_nik VARCHAR(50) NOT NULL,
    member_name VARCHAR(150) NOT NULL,
    resignation_effective_date DATE NOT NULL,
    reason TEXT NOT NULL,
    refund_simpanan_pokok NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    refund_simpanan_wajib NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    refund_simpanan_sukarela NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    refund_bagi_hasil_bunga NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    deduction_outstanding_loans NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    destination_bank VARCHAR(50) NOT NULL,
    destination_account_number VARCHAR(50) NOT NULL,
    destination_account_holder VARCHAR(150) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'submitted' CHECK (status IN (
        'submitted',
        'verifiedByHR',
        'approvedByKoperasi',
        'disbursed',
        'rejected'
    )),
    approved_by_admin VARCHAR(150),
    rejection_reason TEXT,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    disbursed_at TIMESTAMP WITH TIME ZONE
);

-- 7. ATURAN KEAMANAN SUPABASE (ROW-LEVEL SECURITY / RLS POLICIES UNTUK ANON KEY)
ALTER TABLE kopkar_cloud_store ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE savings_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE resignation_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow App Sync Store" ON kopkar_cloud_store;
CREATE POLICY "Allow App Sync Store" ON kopkar_cloud_store FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow App Admins Access" ON admins;
CREATE POLICY "Allow App Admins Access" ON admins FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow App Members Access" ON members;
CREATE POLICY "Allow App Members Access" ON members FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow App Transactions Access" ON savings_transactions;
CREATE POLICY "Allow App Transactions Access" ON savings_transactions FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow App Loans Access" ON loans;
CREATE POLICY "Allow App Loans Access" ON loans FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow App Resignations Access" ON resignation_claims;
CREATE POLICY "Allow App Resignations Access" ON resignation_claims FOR ALL USING (true) WITH CHECK (true);
