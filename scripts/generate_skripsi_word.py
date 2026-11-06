#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script to generate the official Form F-KPS-1305 (Persetujuan Pengajuan Judul Skripsi / Non-Skripsi Proyek Prototipe)
for Universitas Teknokrat Indonesia - Program Studi Informatika.
Mahasiswa: Muhammad Fahmi (NPM: 23312221)
Mitra: PT Budi Berlian Motor
"""

import os
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn

def create_document():
    doc = docx.Document()

    # 1. Page Margins (Normal academic form margins: 2.54 cm / 1 inch)
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        section.page_width = Inches(8.27)   # A4
        section.page_height = Inches(11.69) # A4

    # Base styling - Times New Roman 11pt (Academic standard)
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Times New Roman'
    normal_style.font.size = Pt(11)
    normal_style.font.color.rgb = RGBColor(0, 0, 0)
    normal_style.paragraph_format.line_spacing = 1.15
    normal_style.paragraph_format.space_after = Pt(2)
    normal_style.paragraph_format.space_before = Pt(0)

    def set_cell_margins(cell, top=100, bottom=100, left=140, right=140):
        tcPr = cell._tc.get_or_add_tcPr()
        tcMar = parse_xml(f'''
            <w:tcMar {nsdecls("w")}>
                <w:top w:w="{top}" w:type="dxa"/>
                <w:bottom w:w="{bottom}" w:type="dxa"/>
                <w:left w:w="{left}" w:type="dxa"/>
                <w:right w:w="{right}" w:type="dxa"/>
            </w:tcMar>
        ''')
        tcPr.append(tcMar)

    def set_cell_shading(cell, color_hex):
        shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{color_hex}"/>')
        cell._tc.get_or_add_tcPr().append(shading)

    def set_table_borders(table, color="000000", sz="4", val="single"):
        tblPr = table._tbl.tblPr
        borders = parse_xml(f'''
            <w:tblBorders {nsdecls("w")}>
                <w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
                <w:left w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
                <w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
                <w:right w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
                <w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
                <w:insideV w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
            </w:tblBorders>
        ''')
        tblPr.append(borders)

    # ==========================================
    # HEADER: Kode Dokumen & Revisi
    # ==========================================
    header_p = doc.add_paragraph()
    header_p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    r1 = header_p.add_run("Kode Dok \t: F-KPS-1305\tRevisi \t: 1")
    r1.font.name = 'Times New Roman'
    r1.font.size = Pt(10)
    r1.font.bold = True
    header_p.paragraph_format.space_after = Pt(10)

    # ==========================================
    # JUDUL FORMULIR
    # ==========================================
    title_p = doc.add_paragraph()
    title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_t1 = title_p.add_run("PERSETUJUAN PENGAJUAN JUDUL\n")
    r_t1.bold = True
    r_t1.font.size = Pt(12)
    r_t2 = title_p.add_run("SKRIPSI / NON-SKRIPSI\n")
    r_t2.bold = True
    r_t2.font.size = Pt(12)
    r_t3 = title_p.add_run("T.A. 2026/ 2027")
    r_t3.bold = True
    r_t3.font.size = Pt(12)
    title_p.paragraph_format.space_after = Pt(12)

    # ==========================================
    # TUJUAN SURAT
    # ==========================================
    yth_p = doc.add_paragraph()
    yth_p.add_run("Yth.\nKetua Program Studi Informatika\nUniversitas Teknokrat Indonesia")
    yth_p.paragraph_format.space_after = Pt(8)

    p_intro = doc.add_paragraph("Dengan ini saya :")
    p_intro.paragraph_format.space_after = Pt(4)

    # ==========================================
    # TABEL IDENTITAS MAHASISWA (Tanpa Border Garis)
    # ==========================================
    id_table = doc.add_table(rows=6, cols=3)
    id_table.alignment = WD_TABLE_ALIGNMENT.LEFT
    id_table.autofit = False

    # Widths: Col 0 = 2.4 inch, Col 1 = 0.2 inch, Col 2 = 3.6 inch
    col_widths = [Inches(2.4), Inches(0.2), Inches(3.6)]

    id_data = [
        ("Nama", ":", "Muhammad Fahmi"),
        ("NPM", ":", "23312221"),
        ("Program Studi", ":", "Informatika"),
        ("Jumlah SKS yang telah ditempuh", ":", "134 SKS  (Jumlah Mata Kuliah: 61)"),
        ("IPK", ":", "3.11"),
        ("Nomor Telepon/HP", ":", "0896-7453-8203"),
    ]

    for row_idx, (k, sep, v) in enumerate(id_data):
        row = id_table.rows[row_idx]
        for c_idx, text in enumerate([k, sep, v]):
            cell = row.cells[c_idx]
            cell.width = col_widths[c_idx]
            set_cell_margins(cell, top=30, bottom=30, left=40, right=40)
            p = cell.paragraphs[0]
            p.paragraph_format.line_spacing = 1.15
            p.paragraph_format.space_after = Pt(1)
            run = p.add_run(text)
            run.font.name = 'Times New Roman'
            run.font.size = Pt(11)
            if c_idx == 2 and row_idx in [0, 1]:
                run.bold = True

    p_spacer = doc.add_paragraph()
    p_spacer.paragraph_format.space_after = Pt(4)

    # ==========================================
    # JENIS PENGAJUAN JUDUL (CHECKBOXES)
    # ==========================================
    jenis_p = doc.add_paragraph()
    jenis_run = jenis_p.add_run("Jenis Pengajuan Judul \t: ")
    jenis_run.bold = True

    # Checkbox lines
    box_p1 = doc.add_paragraph()
    box_p1.paragraph_format.left_indent = Inches(0.4)
    box_p1.add_run("[   ]  Skripsi")

    box_p2 = doc.add_paragraph()
    box_p2.paragraph_format.left_indent = Inches(0.4)
    r_non = box_p2.add_run("[ ✓ ] Non-Skripsi :")
    r_non.bold = True

    box_p3 = doc.add_paragraph()
    box_p3.paragraph_format.left_indent = Inches(0.8)
    box_p3.add_run("[   ]  Publikasi Karya Ilmiah :")

    box_p4 = doc.add_paragraph()
    box_p4.paragraph_format.left_indent = Inches(1.2)
    box_p4.add_run("[   ]  Conference International terindeks scopus\n"
                   "[   ]  Jurnal Internasional terindeks scopus\n"
                   "[   ]  Jurnal Nasional SINTA 1 - 4")

    box_p5 = doc.add_paragraph()
    box_p5.paragraph_format.left_indent = Inches(0.8)
    r_proto = box_p5.add_run("[ ✓ ] Proyek Prototipe")
    r_proto.bold = True
    box_p5.paragraph_format.space_after = Pt(8)

    # ==========================================
    # TABEL USULAN JUDUL PROPOSAL (Border Kotak Hitam)
    # ==========================================
    t_judul = doc.add_table(rows=7, cols=2)
    t_judul.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(t_judul, color="000000", sz="6", val="single")

    # Header Row (Merged across both columns)
    hdr_cell = t_judul.cell(0, 0)
    hdr_cell.merge(t_judul.cell(0, 1))
    set_cell_shading(hdr_cell, "F2F2F2")
    set_cell_margins(hdr_cell, top=100, bottom=100, left=140, right=140)
    p_hdr = hdr_cell.paragraphs[0]
    r_hdr = p_hdr.add_run("Usulan judul proposal skripsi atau non-skripsi dengan :")
    r_hdr.bold = True
    r_hdr.font.size = Pt(11)

    table_data = [
        # (Row, Label, Value, is_bold, is_italic)
        (1, "1. Judul (Bahasa Indonesia)", 
         ": Aplikasi Mobile Koperasi Karyawan Berbasis Flutter dengan Otomatisasi Pemotongan Payroll dan Distribusi Sisa Hasil Usaha (Studi Kasus: PT Budi Berlian Motor)", 
         True, False),
        (2, "   Judul (Bahasa Inggris)", 
         ": Flutter-Based Employee Cooperative Mobile Application with Automated Payroll Deduction and Business Surplus Distribution (Case Study: PT Budi Berlian Motor)", 
         False, True),
        (3, "2. Judul (Bahasa Indonesia)", 
         ": Aplikasi Mobile Layanan Simpan Pinjam Koperasi Karyawan Berbasis Flutter dengan Penerapan Keamanan Bank-Grade dan Dual-Token Authentication (Studi Kasus: PT Budi Berlian Motor)", 
         True, False),
        (4, "   Judul (Bahasa Inggris)", 
         ": Flutter-Based Employee Cooperative Savings and Loan Mobile Application with Bank-Grade Security Implementation and Dual-Token Authentication (Case Study: PT Budi Berlian Motor)", 
         False, True),
        (5, "Tempat Penelitian", 
         ": PT Budi Berlian Motor (Authorized Dealer Mitsubishi Motors Lampung)", 
         True, False),
        (6, "Dosen Pembimbing*)", 
         ": …………………………………………………………………………………", 
         False, False),
    ]

    w_left = Inches(2.2)
    w_right = Inches(4.0)

    for row_idx, lbl, val, is_b, is_i in table_data:
        cell_l = t_judul.cell(row_idx, 0)
        cell_r = t_judul.cell(row_idx, 1)
        cell_l.width = w_left
        cell_r.width = w_right
        set_cell_margins(cell_l, top=80, bottom=80, left=120, right=120)
        set_cell_margins(cell_r, top=80, bottom=80, left=120, right=120)

        p_l = cell_l.paragraphs[0]
        p_l.paragraph_format.line_spacing = 1.15
        p_l.paragraph_format.space_after = Pt(0)
        r_l = p_l.add_run(lbl)
        r_l.font.name = 'Times New Roman'
        r_l.font.size = Pt(10.5)
        if "Judul" in lbl or "Tempat" in lbl:
            r_l.bold = True

        p_r = cell_r.paragraphs[0]
        p_r.paragraph_format.line_spacing = 1.15
        p_r.paragraph_format.space_after = Pt(0)
        r_r = p_r.add_run(val)
        r_r.font.name = 'Times New Roman'
        r_r.font.size = Pt(10.5)
        r_r.bold = is_b
        r_r.italic = is_i

    p_sp2 = doc.add_paragraph()
    p_sp2.paragraph_format.space_after = Pt(8)

    # ==========================================
    # TANDA TANGAN (KAPRODI & PENGUSUL)
    # ==========================================
    t_ttd = doc.add_table(rows=1, cols=2)
    t_ttd.alignment = WD_TABLE_ALIGNMENT.CENTER
    col_w_ttd = Inches(3.1)
    t_ttd.rows[0].cells[0].width = col_w_ttd
    t_ttd.rows[0].cells[1].width = col_w_ttd

    # Left cell: Ketua Program Studi
    c_kps = t_ttd.rows[0].cells[0]
    p_kps = c_kps.paragraphs[0]
    p_kps.alignment = WD_ALIGN_PARAGRAPH.LEFT
    p_kps.paragraph_format.line_spacing = 1.15
    p_kps.add_run("\nKetua Program Studi,\n\n\n\n\n")
    r_kps_name = p_kps.add_run("Dr. Heni Sulistiani, S.Kom., M.Kom.\n")
    r_kps_name.bold = True
    r_kps_name.underline = True
    p_kps.add_run("NIK. 022 13 02 11")

    # Right cell: Pengusul Mahasiswa
    c_mhs = t_ttd.rows[0].cells[1]
    p_mhs = c_mhs.paragraphs[0]
    p_mhs.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p_mhs.paragraph_format.line_spacing = 1.15
    p_mhs.add_run("Bandar Lampung, 6 November 2026\nPengusul,\n\n\n\n\n")
    r_mhs_name = p_mhs.add_run("Muhammad Fahmi\n")
    r_mhs_name.bold = True
    r_mhs_name.underline = True
    p_mhs.add_run("NPM. 23312221")

    p_note_star = doc.add_paragraph()
    p_note_star.paragraph_format.space_before = Pt(6)
    p_note_star.paragraph_format.space_after = Pt(2)
    r_star = p_note_star.add_run("*) diisi oleh Ketua Program Studi")
    r_star.font.size = Pt(9.5)
    r_star.italic = True

    # ==========================================
    # CATATAN KETENTUAN (Tabel 2 Kolom)
    # ==========================================
    p_cat = doc.add_paragraph()
    p_cat.paragraph_format.space_after = Pt(3)
    r_cat_title = p_cat.add_run("Catatan :\nKetentuan publikasi karya ilmiah dan proyek prototipe dimaksud sebagai berikut :")
    r_cat_title.font.size = Pt(9.5)
    r_cat_title.bold = True

    t_ket = doc.add_table(rows=2, cols=2)
    t_ket.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(t_ket, color="000000", sz="4", val="single")

    # Headers
    h_pub = t_ket.cell(0, 0)
    h_pro = t_ket.cell(0, 1)
    set_cell_shading(h_pub, "F2F2F2")
    set_cell_shading(h_pro, "F2F2F2")
    set_cell_margins(h_pub, top=60, bottom=60, left=100, right=100)
    set_cell_margins(h_pro, top=60, bottom=60, left=100, right=100)

    p_hp = h_pub.paragraphs[0]
    p_hp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_hp = p_hp.add_run("Publikasi Karya Ilmiah")
    r_hp.bold = True
    r_hp.font.size = Pt(9.5)

    p_hr = h_pro.paragraphs[0]
    p_hr.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_hr = p_hr.add_run("Proyek Prototipe")
    r_hr.bold = True
    r_hr.font.size = Pt(9.5)

    # Body Content
    c_b_pub = t_ket.cell(1, 0)
    c_b_pro = t_ket.cell(1, 1)
    set_cell_margins(c_b_pub, top=60, bottom=60, left=100, right=100)
    set_cell_margins(c_b_pro, top=60, bottom=60, left=100, right=100)

    p_bp = c_b_pub.paragraphs[0]
    p_bp.paragraph_format.line_spacing = 1.1
    p_bp.paragraph_format.space_after = Pt(0)
    r_bp = p_bp.add_run(
        "a.  Publikasi karya ilmiah dapat diusulkan secara mandiri;\n"
        "b.  Mahasiswa dinyatakan lulus jika minimal mendapatkan Letter of Acceptance (LoA) dari penerbit jurnal atau penyelenggara conference;\n"
        "c.  Biaya publikasi dibebankan kepada mahasiswa."
    )
    r_bp.font.size = Pt(9)

    p_br = c_b_pro.paragraphs[0]
    p_br.paragraph_format.line_spacing = 1.1
    p_br.paragraph_format.space_after = Pt(0)
    r_br = p_br.add_run(
        "a.  Proyek prototipe dapat diusulkan secara mandiri atau kelompok (maksimal 3 mahasiswa);\n"
        "b.  Mahasiswa dinyatakan lulus dengan menyerahkan bukti proyek prototipe seperti :\n"
        "     •  Bukti berita acara serah terima hasil proyek prototipe ke mitra pengguna\n"
        "     •  Foto atau dokumentasi penyerahan hasil proyek prototipe ke mitra pengguna manfaat\n"
        "     •  Deskripsi tentang produk prototipe yang dihasilkan;\n"
        "c.  Biaya proyek prototipe dibebankan kepada mahasiswa."
    )
    r_br.font.size = Pt(9)

    # ==========================================
    # HALAMAN BARU: PEMAPARAN JUDUL 1 & 2
    # ==========================================
    doc.add_page_break()

    p_pem_head = doc.add_paragraph()
    p_pem_head.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_ph = p_pem_head.add_run("DESKRIPSI DAN PEMAPARAN USULAN PROYEK PROTOTIPE\nTAHUN AKADEMIK 2026/2027")
    r_ph.bold = True
    r_ph.font.size = Pt(12)
    p_pem_head.paragraph_format.space_after = Pt(14)

    # ------------------------------------------
    # PEMAPARAN JUDUL 1
    # ------------------------------------------
    p_j1_title = doc.add_paragraph()
    r_j1_h = p_j1_title.add_run("Pemaparan Judul 1 (Pilihan Utama):")
    r_j1_h.bold = True
    r_j1_h.font.size = Pt(11.5)
    p_j1_title.paragraph_format.space_after = Pt(2)

    p_j1_name = doc.add_paragraph()
    r_j1_n = p_j1_name.add_run("Aplikasi Mobile Koperasi Karyawan Berbasis Flutter dengan Otomatisasi Pemotongan Payroll dan Distribusi Sisa Hasil Usaha (Studi Kasus: PT Budi Berlian Motor)")
    r_j1_n.bold = True
    r_j1_n.italic = True
    r_j1_n.font.size = Pt(11)
    p_j1_name.paragraph_format.space_after = Pt(6)

    p_j1_body = doc.add_paragraph()
    p_j1_body.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p_j1_body.paragraph_format.line_spacing = 1.15
    p_j1_body.paragraph_format.space_after = Pt(10)
    p_j1_body.add_run(
        "Koperasi Karyawan (KOPKAR) PT Budi Berlian Motor merupakan entitas penting dalam memfasilitasi kebutuhan finansial, kesejahteraan, serta simpan pinjam bagi seluruh karyawan perusahaan. Namun, saat ini proses operasional koperasi masih menghadapi kendala utama berupa rekapitulasi data simpanan dan pinjaman yang semi-manual, potensi selisih hitung potongan payroll slip gaji bulanan, minimnya transparansi pembagian bunga pinjaman sebagai Sisa Hasil Usaha (SHU), serta proses klaim pengembalian dana simpanan yang memakan waktu lama ketika karyawan mengundurkan diri (resign).\n\n"
        "Rancang bangun prototipe yang dibangun murni dari awal (from scratch) ini bertujuan untuk mendesain dan mengimplementasikan platform aplikasi mobile terintegrasi (Android & iOS) menggunakan framework Flutter. Prototipe ini secara komprehensif mengotomatiskan dan mendigitalkan seluruh siklus bisnis koperasi karyawan end-to-end dengan keunggulan fungsional utama:\n"
        "1. Otomatisasi Pemotongan Payroll Bulanan (Automated Payroll Deduction): Sistem secara otomatis membedakan iuran perdana anggota baru (terpotong Rp 125.000, terdiri atas Simpanan Pokok Rp 100.000 yang hanya dibayar 1x seumur hidup dan Simpanan Wajib Rp 25.000) dengan iuran rutin bulanan karyawan tetap (terpotong Rp 25.000/bulan).\n"
        "2. Pengelolaan Pinjaman Anggota & Distribusi Bunga 1% (SHU): Peminjaman dana menerapkan bunga flat 1% per bulan (tenor 1-12 bulan). Seluruh akumulasi bunga 1% yang dibayarkan oleh para peminjam aktif secara otomatis dikumpulkan dan didistribusikan secara transparan dan proporsional kepada seluruh anggota aktif koperasi setiap bulan sebagai saldo bagi hasil (SHU).\n"
        "3. Tabungan Sukarela & Pencetakan E-Statement PDF: Memfasilitasi fleksibilitas setor dan tarik saldo simpanan sukarela dengan verifikasi bukti transfer fisik/digital, serta penyediaan fitur unduh buku tabungan digital (E-Statement PDF) secara instan.\n"
        "4. Jaminan 100% Refund Hak Simpanan Resign: Menghitung secara otomatis dan presisi seluruh hak pengembalian dana karyawan saat mengundurkan diri (Total Refund = Simpanan Pokok + Simpanan Wajib + Simpanan Sukarela + Bagi Hasil Bunga 1% dikurangi Sisa Pinjaman Berjalan).\n"
        "5. Dual Panel Interaktif: Panel Member Self-Service untuk karyawan dan Dashboard Admin Pengurus untuk eksekusi batch auto-debit payroll, persetujuan pinjaman, persetujuan simpanan, dan verifikasi pelunasan dipercepat.\n\n"
        "Prototipe ini diharapkan dapat meningkatkan efisiensi operasional pengurus koperasi hingga 80%, mengeliminasi risiko kesalahan pencatatan akuntansi, memberikan transparansi finansial penuh bagi seluruh karyawan PT Budi Berlian Motor, dan mempercepat rekonsiliasi keuangan perusahaan."
    )

    # ------------------------------------------
    # PEMAPARAN JUDUL 2
    # ------------------------------------------
    p_j2_title = doc.add_paragraph()
    r_j2_h = p_j2_title.add_run("Pemaparan Judul 2 (Pilihan Alternatif):")
    r_j2_h.bold = True
    r_j2_h.font.size = Pt(11.5)
    p_j2_title.paragraph_format.space_after = Pt(2)

    p_j2_name = doc.add_paragraph()
    r_j2_n = p_j2_name.add_run("Aplikasi Mobile Layanan Simpan Pinjam Koperasi Karyawan Berbasis Flutter dengan Penerapan Keamanan Bank-Grade dan Dual-Token Authentication (Studi Kasus: PT Budi Berlian Motor)")
    r_j2_n.bold = True
    r_j2_n.italic = True
    r_j2_n.font.size = Pt(11)
    p_j2_name.paragraph_format.space_after = Pt(6)

    p_j2_body = doc.add_paragraph()
    p_j2_body.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p_j2_body.paragraph_format.line_spacing = 1.15
    p_j2_body.paragraph_format.space_after = Pt(14)
    p_j2_body.add_run(
        "Layanan finansial simpan pinjam berbasis mobile di lingkungan korporasi menuntut tingkat integritas data dan keamanan yang sangat tinggi, mengingat transaksi melibatkan saldo dana riil karyawan dan kredensial perbankan perusahaan. Kerentanan seperti pencurian sesi (session hijacking), kebocoran token otentikasi, serangan pengulangan transaksi (replay attack), hingga pengambilan tangkapan layar liar (unauthorized screenshot) dapat membahayakan privasi dan dana anggota koperasi.\n\n"
        "Pembangunan prototipe yang dirancang dan dibangun murni dari awal (from scratch) ini menitikberatkan pada implementasi arsitektur keamanan tingkat perbankan (Bank-Grade Security Architecture) pada aplikasi mobile koperasi karyawan PT Budi Berlian Motor menggunakan Flutter. Fitur keamanan utama yang diimplementasikan meliputi:\n"
        "1. Dual-Token Authentication dengan Refresh Token Rotation (RTR): Menggabungkan Access Token berumur pendek (15 menit) dan Refresh Token (30 hari) yang secara otomatis diperbarui (rotated) setiap kali sesi digunakan kembali, sehingga meminimalkan jendela waktu eksploitasi jika token dicegat.\n"
        "2. Anti-Theft Replay Attack Detection: Mekanisme pendeteksi token yang telah usang atau digunakan kembali secara ilegal. Jika terjadi indikasi pencurian token, sistem secara otomatis mengunci (lockout) seluruh sesi anggota untuk melindungi saldo.\n"
        "3. Hardware MAC Address Binding & Enkripsi AES-256 GCM: Token otentikasi dienkripsi menggunakan kunci perangkat keras (Android Keystore / Hardware-backed AES-256) dan terikat dengan alamat MAC fisik perangkat pengguna.\n"
        "4. FLAG_SECURE & Inactivity Auto-Lock: Mencegah tangkapan layar (anti-screenshot) dan perekaman layar secara native pada menu-menu sensitif saldo, serta penguncian layar otomatis jika aplikasi tidak digunakan selama 3 menit.\n"
        "5. Input Sanitization & Anti-CSRF Engine: Menetralkan potensi serangan Cross-Site Scripting (XSS), SQL Injection, serta Cross-Site Request Forgery (CSRF) sesuai standar OWASP ASVS Level 3.\n\n"
        "Melalui penerapan standar keamanan ini, prototipe aplikasi tidak hanya menjamin kelancaran transaksi simpan pinjam anggota, tetapi juga memberikan jaminan perlindungan data finansial karyawan PT Budi Berlian Motor sesuai kaidah rekayasa perangkat lunak modern."
    )

    # Bottom Signature
    p_sig_bottom = doc.add_paragraph()
    p_sig_bottom.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p_sig_bottom.paragraph_format.line_spacing = 1.15
    p_sig_bottom.add_run("Bandar Lampung, 6 November 2026\nPengusul,\n\n\n\n\n")
    r_bottom_mhs = p_sig_bottom.add_run("Muhammad Fahmi\n")
    r_bottom_mhs.bold = True
    r_bottom_mhs.underline = True
    p_sig_bottom.add_run("NPM. 23312221")

    # Output paths
    output_paths = [
        "/Users/fahmi/Downloads/Pengajuan_Judul_Skripsi_Muhammad_Fahmi_23312221.docx",
        "/Users/fahmi/Desktop/Pengajuan_Judul_Skripsi_Muhammad_Fahmi_23312221.docx",
        "/Users/fahmi/.gemini/antigravity/scratch/kopkar_app/docs/Pengajuan_Judul_Skripsi_Muhammad_Fahmi_23312221.docx"
    ]

    for p in output_paths:
        doc.save(p)
        print(f"File successfully created: {p}")

if __name__ == "__main__":
    create_document()
