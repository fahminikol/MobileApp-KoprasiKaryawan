#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script to generate the official Form F-KPS-1305 in PDF format using ReportLab.
Universitas Teknokrat Indonesia - Program Studi Informatika.
Mahasiswa: Muhammad Fahmi (NPM: 23312221)
Mitra: PT Budi Berlian Motor
Ensures strictly 2 pages total (Page 1: Form, Page 2: Pemaparan).
"""

import os
import re
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
)

def generate_pdf():
    pdf_paths = [
        "/Users/fahmi/Downloads/Pengajuan_Judul_Skripsi_Muhammad_Fahmi_23312221.pdf",
        "/Users/fahmi/Desktop/Pengajuan_Judul_Skripsi_Muhammad_Fahmi_23312221.pdf",
        "/Users/fahmi/.gemini/antigravity/scratch/kopkar_app/docs/Pengajuan_Judul_Skripsi_Muhammad_Fahmi_23312221.pdf",
    ]

    # Styles using Times-Roman (Standard Academic)
    style_header_doc = ParagraphStyle(
        'DocHeader',
        fontName='Times-Bold',
        fontSize=8.5,
        leading=10,
        alignment=2 # Right
    )

    style_title = ParagraphStyle(
        'MainTitle',
        fontName='Times-Bold',
        fontSize=10.5,
        leading=12.5,
        alignment=1 # Center
    )

    style_body = ParagraphStyle(
        'Body',
        fontName='Times-Roman',
        fontSize=9,
        leading=11,
        alignment=0 # Left
    )

    style_body_justify = ParagraphStyle(
        'BodyJustify',
        fontName='Times-Roman',
        fontSize=8.5,
        leading=11.5,
        alignment=4 # Justify
    )

    style_table_cell = ParagraphStyle(
        'TableCell',
        fontName='Times-Roman',
        fontSize=8.5,
        leading=10.5,
        alignment=0
    )

    style_table_cell_bold = ParagraphStyle(
        'TableCellBold',
        fontName='Times-Bold',
        fontSize=8.5,
        leading=10.5,
        alignment=0
    )

    style_table_cell_italic = ParagraphStyle(
        'TableCellItalic',
        fontName='Times-Italic',
        fontSize=8.5,
        leading=10.5,
        alignment=0
    )

    style_note = ParagraphStyle(
        'NoteText',
        fontName='Times-Italic',
        fontSize=7.5,
        leading=9,
        alignment=0
    )

    style_catatan = ParagraphStyle(
        'CatatanText',
        fontName='Times-Roman',
        fontSize=7.5,
        leading=9.5,
        alignment=0
    )

    story = []

    # ==========================================
    # HALAMAN 1: FORMULIR F-KPS-1305
    # ==========================================
    # 1. Header Kode Dokumen & Revisi
    story.append(Paragraph("Kode Dok \t: F-KPS-1305 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Revisi \t: 1", style_header_doc))
    story.append(Spacer(1, 4))

    # 2. Judul Formulir
    story.append(Paragraph("PERSETUJUAN PENGAJUAN JUDUL<br/>SKRIPSI / NON-SKRIPSI<br/>T.A. 2026/ 2027", style_title))
    story.append(Spacer(1, 5))

    # 3. Yth & Pengantar
    story.append(Paragraph("Yth.<br/>Ketua Program Studi Informatika<br/>Universitas Teknokrat Indonesia", style_body))
    story.append(Spacer(1, 3))
    story.append(Paragraph("Dengan ini saya :", style_body))
    story.append(Spacer(1, 2))

    # 4. Tabel Identitas Mahasiswa (Tanpa border)
    id_data = [
        [Paragraph("Nama", style_body), Paragraph(":", style_body), Paragraph("<b>Muhammad Fahmi</b>", style_body)],
        [Paragraph("NPM", style_body), Paragraph(":", style_body), Paragraph("<b>23312221</b>", style_body)],
        [Paragraph("Program Studi", style_body), Paragraph(":", style_body), Paragraph("Informatika", style_body)],
        [Paragraph("Jumlah SKS yang telah ditempuh", style_body), Paragraph(":", style_body), Paragraph("134 SKS &nbsp;(Jumlah Mata Kuliah Diambil: 61)", style_body)],
        [Paragraph("IPK", style_body), Paragraph(":", style_body), Paragraph("3.11", style_body)],
        [Paragraph("Nomor Telepon/HP", style_body), Paragraph(":", style_body), Paragraph("0896-7453-8203", style_body)],
    ]
    t_id = Table(id_data, colWidths=[2.1*inch, 0.15*inch, 4.65*inch])
    t_id.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 0.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0.5),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(t_id)
    story.append(Spacer(1, 3))

    # 5. Checklist Jenis Pengajuan
    story.append(Paragraph("<b>Jenis Pengajuan Judul &nbsp;:</b>", style_body))
    check_text = (
        "&nbsp;&nbsp;&nbsp;&nbsp;[ &nbsp; ] &nbsp;Skripsi<br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;<b>[ ✓ ] Non-Skripsi :</b><br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[ &nbsp; ] &nbsp;Publikasi Karya Ilmiah :<br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[ &nbsp; ] Conference International terindeks scopus<br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[ &nbsp; ] Jurnal Internasional terindeks scopus<br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[ &nbsp; ] Jurnal Nasional SINTA 1 - 4<br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>[ ✓ ] Proyek Prototipe</b>"
    )
    story.append(Paragraph(check_text, style_body))
    story.append(Spacer(1, 4))

    # 6. Tabel Usulan Judul Proposal (Border Hitam Penuh)
    judul_rows = [
        [Paragraph("<b>Usulan judul proposal skripsi atau non-skripsi dengan :</b>", style_table_cell_bold), ""],
        [
            Paragraph("<b>1. Judul (Bahasa Indonesia)</b>", style_table_cell_bold),
            Paragraph(": <b>Aplikasi Mobile Koperasi Karyawan Berbasis Flutter dengan Otomatisasi Pemotongan Payroll dan Distribusi Sisa Hasil Usaha (Studi Kasus: PT Budi Berlian Motor)</b>", style_table_cell)
        ],
        [
            Paragraph("&nbsp;&nbsp;&nbsp;&nbsp;Judul (Bahasa Inggris)", style_table_cell),
            Paragraph(": <i>Flutter-Based Employee Cooperative Mobile Application with Automated Payroll Deduction and Business Surplus Distribution (Case Study: PT Budi Berlian Motor)</i>", style_table_cell_italic)
        ],
        [
            Paragraph("<b>2. Judul (Bahasa Indonesia)</b>", style_table_cell_bold),
            Paragraph(": <b>Aplikasi Mobile Layanan Simpan Pinjam Koperasi Karyawan Berbasis Flutter dengan Penerapan Keamanan Bank-Grade dan Dual-Token Authentication (Studi Kasus: PT Budi Berlian Motor)</b>", style_table_cell)
        ],
        [
            Paragraph("&nbsp;&nbsp;&nbsp;&nbsp;Judul (Bahasa Inggris)", style_table_cell),
            Paragraph(": <i>Flutter-Based Employee Cooperative Savings and Loan Mobile Application with Bank-Grade Security Implementation and Dual-Token Authentication (Case Study: PT Budi Berlian Motor)</i>", style_table_cell_italic)
        ],
        [
            Paragraph("<b>Tempat Penelitian</b>", style_table_cell_bold),
            Paragraph(": <b>PT Budi Berlian Motor (Authorized Dealer Mitsubishi Motors Lampung)</b>", style_table_cell)
        ],
        [
            Paragraph("Dosen Pembimbing*)", style_table_cell),
            Paragraph(": …………………………………………………………………………………", style_table_cell)
        ],
    ]

    t_judul = Table(judul_rows, colWidths=[2.0*inch, 4.9*inch])
    t_judul.setStyle(TableStyle([
        ('SPAN', (0,0), (1,0)),
        ('BACKGROUND', (0,0), (1,0), colors.HexColor('#F2F2F2')),
        ('BOX', (0,0), (-1,-1), 0.7, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.4, colors.black),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(t_judul)
    story.append(Spacer(1, 5))

    # 7. Tanda Tangan (Kaprodi & Pengusul)
    ttd_data = [
        [
            Paragraph("Ketua Program Studi,<br/><br/><br/><br/><b><u>Dr. Heni Sulistiani, S.Kom., M.Kom.</u></b><br/>NIK. 022 13 02 11", style_body),
            Paragraph("Bandar Lampung, 6 November 2026<br/>Pengusul,<br/><br/><br/><br/><b><u>Muhammad Fahmi</u></b><br/>NPM. 23312221", style_body)
        ]
    ]
    t_ttd = Table(ttd_data, colWidths=[3.45*inch, 3.45*inch])
    t_ttd.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('ALIGN', (1,0), (1,0), 'RIGHT'),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(t_ttd)

    story.append(Spacer(1, 2))
    story.append(Paragraph("*) diisi oleh Ketua Program Studi", style_note))
    story.append(Spacer(1, 3))

    # 8. Tabel Catatan Ketentuan Publikasi vs Proyek Prototipe
    story.append(Paragraph("<b>Catatan :</b><br/>Ketentuan publikasi karya ilmiah dan proyek prototipe dimaksud sebagai berikut :", style_note))
    story.append(Spacer(1, 2))

    cat_rows = [
        [
            Paragraph("<b>Publikasi Karya Ilmiah</b>", ParagraphStyle('H1', fontName='Times-Bold', fontSize=7.5, leading=9, alignment=1)),
            Paragraph("<b>Proyek Prototipe</b>", ParagraphStyle('H2', fontName='Times-Bold', fontSize=7.5, leading=9, alignment=1))
        ],
        [
            Paragraph(
                "a. Publikasi karya ilmiah dapat diusulkan secara mandiri;<br/>"
                "b. Mahasiswa dinyatakan lulus jika minimal mendapatkan Letter of Acceptance (LoA) dari penerbit jurnal atau penyelenggara conference;<br/>"
                "c. Biaya publikasi dibebankan kepada mahasiswa.",
                style_catatan
            ),
            Paragraph(
                "a. Proyek prototipe dapat diusulkan secara mandiri atau kelompok (maksimal 3 mahasiswa);<br/>"
                "b. Mahasiswa dinyatakan lulus dengan menyerahkan bukti proyek prototipe seperti :<br/>"
                "&nbsp;&nbsp;&nbsp;&nbsp;• Bukti berita acara serah terima hasil proyek prototipe ke mitra pengguna<br/>"
                "&nbsp;&nbsp;&nbsp;&nbsp;• Foto atau dokumentasi penyerahan hasil proyek prototipe ke mitra pengguna manfaat<br/>"
                "&nbsp;&nbsp;&nbsp;&nbsp;• Deskripsi tentang produk prototipe yang dihasilkan;<br/>"
                "c. Biaya proyek prototipe dibebankan kepada mahasiswa.",
                style_catatan
            )
        ]
    ]
    t_cat = Table(cat_rows, colWidths=[3.2*inch, 3.7*inch])
    t_cat.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (1,0), colors.HexColor('#F2F2F2')),
        ('BOX', (0,0), (-1,-1), 0.4, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.4, colors.black),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
    ]))
    story.append(t_cat)

    # ==========================================
    # HALAMAN 2: DESKRIPSI & PEMAPARAN JUDUL
    # ==========================================
    story.append(PageBreak())

    story.append(Paragraph("<b>DESKRIPSI DAN PEMAPARAN USULAN PROYEK PROTOTIPE<br/>TAHUN AKADEMIK 2026/2027</b>", style_title))
    story.append(Spacer(1, 8))

    # Pemaparan Judul 1
    story.append(Paragraph("<b>Pemaparan Judul 1 (Pilihan Utama):</b>", ParagraphStyle('J1H', fontName='Times-Bold', fontSize=9.5, leading=12)))
    story.append(Paragraph("<b><i>Aplikasi Mobile Koperasi Karyawan Berbasis Flutter dengan Otomatisasi Pemotongan Payroll dan Distribusi Sisa Hasil Usaha (Studi Kasus: PT Budi Berlian Motor)</i></b>", ParagraphStyle('J1N', fontName='Times-BoldItalic', fontSize=9, leading=11)))
    story.append(Spacer(1, 3))
    
    j1_desc = (
        "Koperasi Karyawan (KOPKAR) PT Budi Berlian Motor memiliki peran vital dalam menyejahterakan karyawan melalui layanan simpan pinjam. Namun, operasional koperasi saat ini masih menghadapi kendala rekapitulasi data manual, potensi selisih hitung potongan slip gaji bulanan (payroll), minimnya transparansi pembagian bunga pinjaman sebagai Sisa Hasil Usaha (SHU), serta lambatnya pencairan hak dana simpanan ketika karyawan mengundurkan diri (resign).<br/><br/>"
        "Prototipe yang dirancang dan dibangun dari awal (from scratch) ini bertujuan mengimplementasikan aplikasi mobile terintegrasi (Android & iOS) berbasis Flutter guna mendigitalkan seluruh siklus bisnis koperasi secara otomatis:<br/>"
        "<b>1. Otomatisasi Pemotongan Payroll Bulanan:</b> Sistem otomatis membedakan iuran perdana anggota baru (Rp 125.000: Simpanan Pokok Rp 100.000 + Simpanan Wajib Rp 25.000) dan iuran rutin bulanan karyawan tetap (Rp 25.000/bulan).<br/>"
        "<b>2. Pengelolaan Pinjaman Anggota & Distribusi Bunga 1% (SHU):</b> Peminjaman menerapkan bunga flat 1%/bulan (tenor 1-12 bulan). Seluruh akumulasi bunga 1% dari para peminjam aktif secara otomatis dikumpulkan dan didistribusikan secara transparan serta proporsional kepada seluruh anggota aktif koperasi setiap bulan sebagai saldo bagi hasil (SHU).<br/>"
        "<b>3. Tabungan Sukarela & Cetak E-Statement PDF:</b> Memfasilitasi fleksibilitas setor dan tarik sukarela dengan verifikasi bukti transfer digital, serta pencetakan buku tabungan digital resmi (E-Statement PDF).<br/>"
        "<b>4. Jaminan 100% Refund Hak Simpanan Resign:</b> Menghitung otomatis hak pengembalian dana utuh saat karyawan resign dengan formula: <i>Total Refund = (Simpanan Pokok + Wajib + Sukarela + Bagi Hasil Bunga 1%) - Sisa Pinjaman</i>.<br/>"
        "<b>5. Dual Panel Interaktif:</b> Member Self-Service untuk karyawan dan Dashboard Admin Pengurus untuk eksekusi batch auto-debit payroll, persetujuan pinjaman, persetujuan simpanan, dan verifikasi pelunasan dipercepat.<br/><br/>"
        "Prototipe ini meningkatkan efisiensi operasional pengurus hingga 80%, mengeliminasi risiko selisih akuntansi, dan memberikan transparansi finansial penuh bagi seluruh karyawan PT Budi Berlian Motor."
    )
    story.append(Paragraph(j1_desc, style_body_justify))
    story.append(Spacer(1, 8))

    # Pemaparan Judul 2
    story.append(Paragraph("<b>Pemaparan Judul 2 (Pilihan Alternatif):</b>", ParagraphStyle('J2H', fontName='Times-Bold', fontSize=9.5, leading=12)))
    story.append(Paragraph("<b><i>Aplikasi Mobile Layanan Simpan Pinjam Koperasi Karyawan Berbasis Flutter dengan Penerapan Keamanan Bank-Grade dan Dual-Token Authentication (Studi Kasus: PT Budi Berlian Motor)</i></b>", ParagraphStyle('J2N', fontName='Times-BoldItalic', fontSize=9, leading=11)))
    story.append(Spacer(1, 3))

    j2_desc = (
        "Layanan finansial simpan pinjam korporasi menuntut tingkat keamanan dan integritas data yang sangat tinggi karena menyangkut saldo riil karyawan dan kredensial perusahaan. Kerentanan seperti session hijacking, kebocoran token otentikasi, serangan replay attack, hingga screenshot liar dapat membahayakan privasi dan dana anggota.<br/><br/>"
        "Pembangunan prototipe dari awal ini menitikberatkan pada implementasi arsitektur keamanan tingkat perbankan (Bank-Grade Security) pada aplikasi mobile koperasi karyawan PT Budi Berlian Motor dengan Flutter:<br/>"
        "<b>1. Dual-Token Authentication & Refresh Token Rotation (RTR):</b> Menggabungkan Access Token (15 menit) dan Refresh Token (30 hari) yang diperbarui otomatis setiap kali sesi digunakan guna meminimalkan risiko pembajakan sesi.<br/>"
        "<b>2. Anti-Theft Replay Attack Detection:</b> Mendeteksi token usang atau digunakan ulang secara ilegal dan otomatis mengunci (lockout) akun untuk mencegah pencurian saldo.<br/>"
        "<b>3. Hardware MAC Address Binding & Enkripsi AES-256 GCM:</b> Token dan data sesi dienkripsi dengan kunci hardware (Android Keystore) yang terikat dengan alamat MAC fisik perangkat pengguna.<br/>"
        "<b>4. FLAG_SECURE & Inactivity Auto-Lock:</b> Mencegah tangkapan layar (anti-screenshot) secara native dan mengunci layar otomatis jika aplikasi tidak digunakan selama 3 menit.<br/>"
        "<b>5. Input Sanitization & Anti-CSRF Engine:</b> Menetralkan serangan XSS, SQL Injection, dan CSRF sesuai standar OWASP ASVS Level 3.<br/><br/>"
        "Penerapan standar ini memberikan jaminan rasa aman dan integritas data penuh bagi karyawan dan manajemen PT Budi Berlian Motor."
    )
    story.append(Paragraph(j2_desc, style_body_justify))
    story.append(Spacer(1, 8))

    # Tanda Tangan Bawah Halaman 2
    story.append(Paragraph(
        "Bandar Lampung, 6 November 2026<br/>"
        "Pengusul,<br/><br/><br/><br/>"
        "<b><u>Muhammad Fahmi</u></b><br/>"
        "NPM. 23312221",
        ParagraphStyle('BottomSig', fontName='Times-Roman', fontSize=9, leading=11.5, alignment=2)
    ))

    # Build PDF for all destinations
    for p in pdf_paths:
        doc = SimpleDocTemplate(
            p,
            pagesize=A4,
            leftMargin=0.6*inch,
            rightMargin=0.6*inch,
            topMargin=0.45*inch,
            bottomMargin=0.45*inch
        )
        doc.build(story)
        print(f"PDF successfully created: {p}")

if __name__ == "__main__":
    generate_pdf()
