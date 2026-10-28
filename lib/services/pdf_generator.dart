import 'dart:convert';
import 'dart:typed_data';
import '../models/member_model.dart';
import '../models/transaction_model.dart';
import 'coop_service.dart';

/// Generator Dokumen PDF 1.4 Asli (A4 Vector PDF Tanpa Library Eksternal Berat)
/// Menghasilkan file .pdf standar yang dapat dibuka di semua PDF Viewer Android, iOS, & PC.
class PdfGenerator {
  static String _escapePdfText(String input) {
    final asciiClean = input
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('÷', '/')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    return asciiClean
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  /// Bangun E-Statement Simpanan & Pinjaman Anggota Resmi (PDF A4)
  static Uint8List generateMemberStatementPdf({
    required MemberModel member,
    required List<TransactionModel> transactions,
    required String coopBankName,
    required String coopBankAccountNumber,
  }) {
    final now = DateTime.now();
    final netRefund =
        (member.totalSavings - member.activeLoanBalance).clamp(0.0, double.infinity);

    final buf = StringBuffer();

    // 1. Header Banner Biru Resmi KOPKAR PT BBM
    buf.writeln('0.09 0.23 0.54 rg');
    buf.writeln('36 742 523 68 re f');

    // Teks Header Putih
    buf.writeln('BT /F2 14 Tf 1 1 1 rg 52 786 Td (KOPERASI KARYAWAN \\(KOPKAR\\) PT BUDI BERLIAN MOTOR) Tj ET');
    buf.writeln('BT /F1 10 Tf 0.85 0.92 1 rg 52 770 Td (E-STATEMENT RESMI SALDO SIMPANAN, PINJAMAN & BAGI HASIL 1%) Tj ET');
    buf.writeln('BT /F1 8.5 Tf 0.85 0.92 1 rg 52 754 Td (Dicetak: ${_escapePdfText(CoopService.formatDate(now))}  |  Status Dokumen: SAH & TERVERIFIKASI SISTEM) Tj ET');

    // 2. Kotak Identitas Anggota
    buf.writeln('0.96 0.97 0.99 rg');
    buf.writeln('36 648 523 82 re f');
    buf.writeln('0.82 0.86 0.91 RG 1 w');
    buf.writeln('36 648 523 82 re S');

    buf.writeln('BT /F2 10.5 Tf 0.08 0.12 0.20 rg 50 712 Td (DATA IDENTITAS ANGGOTA KOPERASI) Tj ET');
    buf.writeln('BT /F1 9.5 Tf 0.20 0.25 0.33 rg 50 694 Td (Nama Lengkap       : ${_escapePdfText(member.name)}) Tj ET');
    buf.writeln('BT /F1 9.5 Tf 0.20 0.25 0.33 rg 50 679 Td (NIK / Departemen   : ${_escapePdfText(member.nik)}  -  ${_escapePdfText(member.department)}) Tj ET');
    buf.writeln('BT /F1 9.5 Tf 0.20 0.25 0.33 rg 50 664 Td (Rekening Terdaftar : ${_escapePdfText(member.bankName)} (${_escapePdfText(member.bankAccountNumber)}) a.n. ${_escapePdfText(member.bankAccountHolder)}) Tj ET');

    // 3. Kotak Ringkasan Saldo Simpanan & Pinjaman
    buf.writeln('0.99 0.99 1.0 rg');
    buf.writeln('36 472 523 162 re f');
    buf.writeln('0.82 0.86 0.91 RG 1 w');
    buf.writeln('36 472 523 162 re S');

    buf.writeln('BT /F2 10.5 Tf 0.09 0.23 0.54 rg 50 616 Td (RINCIAN POSISI SALDO SIMPANAN & KEWAJIBAN PINJAMAN) Tj ET');

    void drawSummaryRow(double y, String label, String val, {bool bold = false, String rgb = '0.12 0.16 0.23'}) {
      final font = bold ? '/F2' : '/F1';
      buf.writeln('BT $font 9.5 Tf $rgb rg 50 $y Td (${_escapePdfText(label)}) Tj ET');
      buf.writeln('BT $font 9.5 Tf $rgb rg 410 $y Td (${_escapePdfText(val)}) Tj ET');
    }

    drawSummaryRow(596, '1. Simpanan Pokok (Wajib Kembali Saat Resign)', CoopService.formatRupiah(member.simpananPokok));
    drawSummaryRow(580, '2. Simpanan Wajib (${member.paidWajibMonths}x Iuran Bulanan)', CoopService.formatRupiah(member.simpananWajib));
    drawSummaryRow(564, '3. Simpanan Sukarela (Bebas Ditarik)', CoopService.formatRupiah(member.simpananSukarela));
    drawSummaryRow(548, '4. Akumulasi Bagi Hasil Bunga Pinjaman 1%', CoopService.formatRupiah(member.saldoBagiHasilBunga));

    buf.writeln('0.82 0.86 0.91 RG 0.8 w 50 538 m 545 538 l S');
    drawSummaryRow(523, 'TOTAL SALDO SIMPANAN BRUTO', CoopService.formatRupiah(member.totalSavings), bold: true, rgb: '0.09 0.23 0.54');
    drawSummaryRow(505, 'Kewajiban Sisa Pinjaman Aktif Berjalan', '- ${CoopService.formatRupiah(member.activeLoanBalance)}', bold: member.activeLoanBalance > 0, rgb: '0.80 0.15 0.15');

    buf.writeln('0.82 0.86 0.91 RG 0.8 w 50 495 m 545 495 l S');
    drawSummaryRow(481, 'ESTIMASI HAK BERSIH ANGGOTA (NET REFUND)', CoopService.formatRupiah(netRefund), bold: true, rgb: '0.06 0.48 0.24');

    // 4. Tabel Riwayat Mutasi Transaksi Terakhir
    buf.writeln('BT /F2 10.5 Tf 0.08 0.12 0.20 rg 36 448 Td (RIWAYAT MUTASI TRANSAKSI TERAKHIR (MAKS 16 TRANSAKSI)) Tj ET');

    // Header Tabel Mutasi
    buf.writeln('0.12 0.18 0.30 rg');
    buf.writeln('36 422 523 20 re f');
    buf.writeln('BT /F2 8.5 Tf 1 1 1 rg 44 429 Td (TANGGAL) Tj ET');
    buf.writeln('BT /F2 8.5 Tf 1 1 1 rg 120 429 Td (JENIS & KETERANGAN TRANSAKSI) Tj ET');
    buf.writeln('BT /F2 8.5 Tf 1 1 1 rg 385 429 Td (STATUS) Tj ET');
    buf.writeln('BT /F2 8.5 Tf 1 1 1 rg 455 429 Td (NOMINAL) Tj ET');

    double rowY = 404;
    final shownTx = transactions.take(16).toList();
    if (shownTx.isEmpty) {
      buf.writeln('BT /F1 9 Tf 0.45 0.50 0.58 rg 44 400 Td (Belum ada riwayat transaksi tercatat.) Tj ET');
    } else {
      for (int i = 0; i < shownTx.length; i++) {
        final tx = shownTx[i];
        if (i.isEven) {
          buf.writeln('0.97 0.98 0.99 rg');
          buf.writeln('36 ${rowY - 5} 523 18 re f');
        }
        final dateStr = CoopService.formatDate(tx.date);
        final descRaw = '${tx.typeLabel}: ${tx.description}';
        final descStr = descRaw.length > 46 ? '${descRaw.substring(0, 43)}...' : descRaw;
        final statusStr = tx.status == TransactionStatus.pending
            ? 'PENDING'
            : (tx.status == TransactionStatus.success ? 'BERHASIL' : 'DITOLAK');
        final sign = tx.isCredit ? '+' : '-';
        final amtStr = '$sign${CoopService.formatRupiah(tx.amount)}';
        final amtColor = tx.status == TransactionStatus.pending
            ? '0.78 0.45 0.05'
            : (tx.isCredit ? '0.06 0.48 0.24' : '0.80 0.15 0.15');

        buf.writeln('BT /F1 8 Tf 0.20 0.25 0.33 rg 44 $rowY Td (${_escapePdfText(dateStr)}) Tj ET');
        buf.writeln('BT /F1 8 Tf 0.12 0.16 0.23 rg 120 $rowY Td (${_escapePdfText(descStr)}) Tj ET');
        buf.writeln('BT /F2 7.5 Tf $amtColor rg 385 $rowY Td (${_escapePdfText(statusStr)}) Tj ET');
        buf.writeln('BT /F2 8 Tf $amtColor rg 455 $rowY Td (${_escapePdfText(amtStr)}) Tj ET');
        rowY -= 19;
      }
    }

    // 5. Footer Legalitas Dokumen
    buf.writeln('0.82 0.86 0.91 RG 0.8 w 36 82 m 559 82 l S');
    buf.writeln('BT /F2 8.5 Tf 0.09 0.23 0.54 rg 36 66 Td (KOPKAR PT BUDI BERLIAN MOTOR  -  Rekening Resmi: ${_escapePdfText(coopBankName)} (${_escapePdfText(coopBankAccountNumber)})) Tj ET');
    buf.writeln('BT /F1 8 Tf 0.40 0.45 0.52 rg 36 52 Td (Dokumen ini diterbitkan secara elektronik oleh Sistem Inti KOPKAR PT BBM dan sah tanpa tanda tangan basah.) Tj ET');

    return _compileSinglePagePdf(buf.toString());
  }

  /// Bangun PDF Rekapitulasi Potongan Gaji Finance untuk Pengurus/HRD
  static Uint8List generatePayrollRecapPdf({
    required int month,
    required int year,
    required List<Map<String, dynamic>> rows,
  }) {
    final now = DateTime.now();
    final buf = StringBuffer();

    buf.writeln('0.09 0.23 0.54 rg');
    buf.writeln('36 742 523 68 re f');
    buf.writeln('BT /F2 13.5 Tf 1 1 1 rg 50 786 Td (REKAPITULASI POTONGAN GAJI KOPERASI \\(DIVISI FINANCE\\)) Tj ET');
    buf.writeln('BT /F1 10 Tf 0.85 0.92 1 rg 50 770 Td (PT BUDI BERLIAN MOTOR  -  Periode Payroll: ${_escapePdfText(CoopService.formatMonthYear(month, year))}) Tj ET');
    buf.writeln('BT /F1 8.5 Tf 0.85 0.92 1 rg 50 754 Td (Tanggal Cetak: ${_escapePdfText(CoopService.formatDate(now))}  |  Jumlah Anggota Aktif: ${rows.length} Karyawan) Tj ET');

    // Header Tabel
    buf.writeln('0.12 0.18 0.30 rg');
    buf.writeln('36 706 523 22 re f');
    buf.writeln('BT /F2 8 Tf 1 1 1 rg 42 714 Td (NIK & NAMA KARYAWAN) Tj ET');
    buf.writeln('BT /F2 8 Tf 1 1 1 rg 210 714 Td (POKOK) Tj ET');
    buf.writeln('BT /F2 8 Tf 1 1 1 rg 280 714 Td (WAJIB) Tj ET');
    buf.writeln('BT /F2 8 Tf 1 1 1 rg 350 714 Td (CICILAN + BUNGA 1%) Tj ET');
    buf.writeln('BT /F2 8 Tf 1 1 1 rg 465 714 Td (TOTAL POTONG) Tj ET');

    double rowY = 688;
    double grandTotal = 0;
    for (int i = 0; i < rows.length && i < 26; i++) {
      final r = rows[i];
      if (i.isEven) {
        buf.writeln('0.96 0.97 0.99 rg');
        buf.writeln('36 ${rowY - 5} 523 19 re f');
      }
      final nameStr = '${r['nik']} - ${r['name']}';
      final cleanName = nameStr.length > 28 ? '${nameStr.substring(0, 25)}...' : nameStr;
      final pokok = (r['pokok'] as num).toDouble();
      final wajib = (r['wajib'] as num).toDouble();
      final loanInst = (r['loanInstallment'] as num).toDouble();
      final total = (r['totalDeduction'] as num).toDouble();
      grandTotal += total;

      buf.writeln('BT /F1 8 Tf 0.12 0.16 0.23 rg 42 $rowY Td (${_escapePdfText(cleanName)}) Tj ET');
      buf.writeln('BT /F1 8 Tf 0.20 0.25 0.33 rg 210 $rowY Td (${_escapePdfText(CoopService.formatRupiah(pokok))}) Tj ET');
      buf.writeln('BT /F1 8 Tf 0.20 0.25 0.33 rg 280 $rowY Td (${_escapePdfText(CoopService.formatRupiah(wajib))}) Tj ET');
      buf.writeln('BT /F1 8 Tf 0.20 0.25 0.33 rg 350 $rowY Td (${_escapePdfText(CoopService.formatRupiah(loanInst))}) Tj ET');
      buf.writeln('BT /F2 8 Tf 0.09 0.23 0.54 rg 465 $rowY Td (${_escapePdfText(CoopService.formatRupiah(total))}) Tj ET');
      rowY -= 20;
    }

    rowY -= 6;
    buf.writeln('0.09 0.23 0.54 rg');
    buf.writeln('36 ${rowY - 6} 523 24 re f');
    buf.writeln('BT /F2 9.5 Tf 1 1 1 rg 44 ${rowY + 2} Td (TOTAL POTONGAN PAYROLL BULAN INI) Tj ET');
    buf.writeln('BT /F2 10 Tf 1 1 1 rg 445 ${rowY + 2} Td (${_escapePdfText(CoopService.formatRupiah(grandTotal))}) Tj ET');

    return _compileSinglePagePdf(buf.toString());
  }

  static Uint8List _compileSinglePagePdf(String contentStream) {
    final streamBytes = ascii.encode(contentStream);
    final objects = <String>[
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
      '5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n',
      '6 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n$contentStream\nendstream\nendobj\n',
    ];

    final out = StringBuffer();
    out.write('%PDF-1.4\n');
    final offsets = <int>[];
    for (final obj in objects) {
      offsets.add(out.length);
      out.write(obj);
    }
    final xrefStart = out.length;
    out.write('xref\n0 ${objects.length + 1}\n');
    out.write('0000000000 65535 f \n');
    for (final offset in offsets) {
      out.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    out.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefStart\n%%EOF\n',
    );
    return Uint8List.fromList(ascii.encode(out.toString()));
  }
}
