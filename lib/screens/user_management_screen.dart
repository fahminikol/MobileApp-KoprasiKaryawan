import 'package:flutter/material.dart';
import '../services/coop_service.dart';
import '../services/input_sanitizer.dart';
import '../theme/app_theme.dart';
import '../models/admin_model.dart';
import '../models/member_model.dart';

class UserManagementScreen extends StatefulWidget {
  final CoopService coopService;

  const UserManagementScreen({
    super.key,
    required this.coopService,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.coopService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Manajemen Pengurus & Anggota'),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primaryBlue,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(
                  icon: const Icon(Icons.people_alt_rounded, size: 18),
                  text: 'Karyawan (${widget.coopService.members.length})',
                ),
                Tab(
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                  text: 'Pengurus (${widget.coopService.admins.length})',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMemberTab(context),
              _buildAdminTab(context),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // TAB 1: MANAJEMEN ANGGOTA (KARYAWAN) + SEARCH BAR (#9, #99)
  // ==========================================================
  Widget _buildMemberTab(BuildContext context) {
    final allMembers = widget.coopService.members;
    final filteredMembers = _searchQuery.trim().isEmpty
        ? allMembers
        : allMembers.where((m) {
            final q = _searchQuery.toLowerCase();
            return m.name.toLowerCase().contains(q) ||
                m.nik.toLowerCase().contains(q) ||
                m.department.toLowerCase().contains(q);
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tombol Daftarkan Anggota Baru
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showAddMemberDialog(context),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Daftarkan Karyawan Baru (Oleh HRD)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Kolom Pencarian Karyawan (#9)
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Cari nama karyawan, NIK, atau departemen...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Karyawan (${filteredMembers.length} Ditemukan)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const Text(
                'Klik kartu untuk rincian',
                style: TextStyle(fontSize: 11, color: AppTheme.primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (filteredMembers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Center(
                child: Text('Karyawan tidak ditemukan.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredMembers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final m = filteredMembers[i];
                final initial = m.name.trim().isNotEmpty ? m.name.trim()[0].toUpperCase() : '?';
                return GestureDetector(
                  onTap: () => _showMemberDetailSheet(context, m),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryBlueLight,
                          child: Text(
                            initial,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      m.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: m.status == MemberStatus.active
                                          ? AppTheme.pastelGreenBg
                                          : AppTheme.pastelYellowBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      m.statusLabel,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: m.status == MemberStatus.active
                                            ? AppTheme.successGreen
                                            : AppTheme.warningOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text('NIK: ${m.nik} • ${m.department}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              Text(
                                'Simpanan: ${CoopService.formatRupiah(m.totalSavings)} • Hutang: ${CoopService.formatRupiah(m.activeLoanBalance)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit Data & Reset PIN',
                          icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryBlue, size: 20),
                          onPressed: () => _showEditMemberDialog(context, m),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Modal Detail Saldo & Pinjaman per Karyawan (#99)
  void _showMemberDetailSheet(BuildContext context, MemberModel m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('NIK: ${m.nik} • ${m.department} (${m.membershipMonths} Bln Kerja)', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primaryBlueLight, borderRadius: BorderRadius.circular(10)),
                  child: Text(m.statusLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                ),
              ],
            ),
            const Divider(height: 22),
            _buildDetailRow('1. Simpanan Pokok', CoopService.formatRupiah(m.simpananPokok)),
            _buildDetailRow('2. Simpanan Wajib (${m.paidWajibMonths}x Iuran)', CoopService.formatRupiah(m.simpananWajib)),
            _buildDetailRow('3. Simpanan Sukarela', CoopService.formatRupiah(m.simpananSukarela)),
            _buildDetailRow('4. Bagi Hasil Bunga 1% (SHU)', CoopService.formatRupiah(m.saldoBagiHasilBunga)),
            const Divider(height: 18),
            _buildDetailRow('Total Akumulasi Simpanan', CoopService.formatRupiah(m.totalSavings), isBold: true),
            _buildDetailRow('Sisa Pinjaman Aktif', CoopService.formatRupiah(m.activeLoanBalance), isDanger: m.activeLoanBalance > 0),
            _buildDetailRow('Plafon Pinjaman Maksimal', CoopService.formatRupiah(m.maxLoanLimit)),
            _buildDetailRow('Rekening Terdaftar', '${m.bankName} - ${m.bankAccountNumber}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditMemberDialog(context, m);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit Data / Reset PIN'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false, bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppTheme.textMuted)),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDanger ? AppTheme.dangerRed : (isBold ? AppTheme.primaryBlue : AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TAB 2: MANAJEMEN PENGURUS (ADMIN) + PROTEKSI RBAC (#4, #36)
  // ==========================================================
  Widget _buildAdminTab(BuildContext context) {
    final admins = widget.coopService.admins;
    final currentAdmin = widget.coopService.currentAdmin;
    final canManageAdmins = currentAdmin?.canManageAdmins ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canManageAdmins)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showAddAdminDialog(context),
                icon: const Icon(Icons.add_moderator_rounded, size: 18),
                label: const Text('Tambah Pengurus Koperasi Baru'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.pastelYellowBg, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'ℹ️ Hanya Super Admin (HRD Master) yang dapat menambah, mereset password, atau menonaktifkan pengurus lain. Anda tetap dapat mengubah password akun Anda sendiri.',
                style: TextStyle(fontSize: 12, color: AppTheme.textDark),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Daftar Akun Pengurus Koperasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: admins.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final a = admins[i];
              final isSelf = a.id == currentAdmin?.id;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(a.role.badgeEmoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${a.name}${isSelf ? ' (Anda)' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(a.role.label, style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: a.isActive ? AppTheme.pastelGreenBg : AppTheme.pastelPinkBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            a.isActive ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: a.isActive ? AppTheme.successGreen : AppTheme.dangerRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text('Email Login: ${a.email}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    Text('No. HP: ${a.phone}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 10),
                    if (canManageAdmins || isSelf)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showEditAdminDialog(
                              context,
                              a,
                              canEditRole: canManageAdmins,
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: Text(
                              isSelf && !canManageAdmins
                                  ? 'Edit Profil & Password Saya'
                                  : 'Edit Data & Password',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (canManageAdmins && !isSelf) ...[
                            TextButton(
                              onPressed: () {
                                final ok = widget.coopService.toggleAdminActive(a.id);
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('⚠️ Tidak dapat menonaktifkan akun sendiri atau Super Admin terakhir!')),
                                  );
                                }
                              },
                              child: Text(
                                a.isActive ? 'Nonaktifkan' : 'Aktifkan',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: a.isActive ? AppTheme.warningOrange : AppTheme.successGreen,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _confirmDeleteAdminDialog(context, a),
                              icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.dangerRed),
                              label: const Text(
                                'Hapus',
                                style: TextStyle(fontSize: 11, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddAdminDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    AdminRole selectedRole = AdminRole.bendahara;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tambah Pengurus Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
                TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Login (Wajib pakai @)')),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password (Min. 6 Karakter)')),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor HP')),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdminRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Jabatan Pengurus'),
                  items: AdminRole.values.map((r) {
                    return DropdownMenuItem(value: r, child: Text('${r.badgeEmoji} ${r.label}'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final nameVal = InputSanitizer.validateName(nameCtrl.text);
                if (!nameVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${nameVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }
                final emailVal = InputSanitizer.validateEmail(emailCtrl.text);
                if (!emailVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${emailVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }
                final passVal = InputSanitizer.validatePassword(passCtrl.text);
                if (!passVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${passVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }
                final phoneVal = InputSanitizer.validatePhone(phoneCtrl.text);
                if (!phoneVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${phoneVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }

                final ok = widget.coopService.addAdmin(
                  name: nameVal.sanitizedValue,
                  email: emailVal.sanitizedValue,
                  password: passVal.sanitizedValue,
                  role: selectedRole,
                  phone: phoneVal.sanitizedValue,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '✅ Pengurus baru berhasil ditambahkan!' : '❌ Gagal: Email sudah terdaftar atau akses ditolak!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAdminDialog(
    BuildContext context,
    AdminModel admin, {
    required bool canEditRole,
  }) {
    final nameCtrl = TextEditingController(text: admin.name);
    final emailCtrl = TextEditingController(text: admin.email);
    final phoneCtrl = TextEditingController(text: admin.phone);
    final passCtrl = TextEditingController(); // Kosongkan agar password rahasia tidak pernah terlihat!
    AdminRole selectedRole = admin.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Edit Data Pengurus: ${admin.name}',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap Pengurus'),
                ),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Login (Wajib pakai @)'),
                ),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Nomor HP / WhatsApp'),
                ),
                const SizedBox(height: 10),
                if (canEditRole)
                  DropdownButtonFormField<AdminRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Jabatan Pengurus'),
                    items: AdminRole.values.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text('${r.badgeEmoji} ${r.label}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => selectedRole = val);
                    },
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password Baru (Opsional)',
                    helperText: 'Kosongkan jika tidak ingin mengubah password',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final ok = widget.coopService.updateAdmin(
                  adminId: admin.id,
                  name: nameCtrl.text,
                  email: emailCtrl.text,
                  phone: phoneCtrl.text,
                  role: selectedRole,
                  newPassword: passCtrl.text,
                );
                if (ok) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Data pengurus ${nameCtrl.text} berhasil diperbarui!'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Gagal: Pastikan Nama diisi, Email belum dipakai akun lain, dan Password minimal 6 karakter!'),
                      backgroundColor: AppTheme.dangerRed,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
              child: const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAdminDialog(BuildContext context, AdminModel admin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Pengurus ${admin.name}?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Apakah Anda yakin ingin menghapus akun pengurus ${admin.name} (${admin.role.label})?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final ok = widget.coopService.deleteAdmin(admin.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '🗑️ Akun pengurus ${admin.name} berhasil dihapus.'
                        : '⚠️ Tidak dapat menghapus akun sendiri atau Super Admin terakhir!',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final nikCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final bankCtrl = TextEditingController(text: 'BCA');
    final rekCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: '123456');
    DateTime joinDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Daftarkan Anggota Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nikCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'NIK Karyawan')),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap Karyawan')),
                TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Departemen / Divisi')),
                TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Karyawan')),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor HP')),
                TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'Nama Bank (BCA/Mandiri/BRI/BNI)')),
                TextField(controller: rekCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nomor Rekening (Min. 8 Angka)')),
                TextField(controller: pinCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'PIN Awal (6 Digit Angka)')),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tgl Masuk: ${CoopService.formatDate(joinDate)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: joinDate,
                          firstDate: DateTime(2000), // Mendukung karyawan senior (#97)
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setStateDialog(() => joinDate = picked);
                        }
                      },
                      child: const Text('Pilih Tanggal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final nikVal = InputSanitizer.validateNik(nikCtrl.text);
                if (!nikVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${nikVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }
                final nameVal = InputSanitizer.validateName(nameCtrl.text);
                if (!nameVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${nameVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }
                final emailVal = InputSanitizer.validateEmail(emailCtrl.text);
                if (!emailVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${emailVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }
                final phoneVal = InputSanitizer.validatePhone(phoneCtrl.text);
                if (!phoneVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${phoneVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }
                final rekVal = InputSanitizer.validateBankAccount(rekCtrl.text);
                if (!rekVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${rekVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }
                final pinVal = InputSanitizer.validatePin(pinCtrl.text, disallowWeak: false);
                if (!pinVal.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${pinVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                  );
                  return;
                }
                final ok = widget.coopService.registerMember(
                  nik: nikVal.sanitizedValue,
                  name: nameVal.sanitizedValue,
                  department: deptCtrl.text,
                  email: emailVal.sanitizedValue,
                  phone: phoneVal.sanitizedValue,
                  joinDate: joinDate,
                  bankName: bankCtrl.text,
                  bankAccountNumber: rekVal.sanitizedValue,
                  initialPin: pinVal.sanitizedValue,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '✅ Karyawan berhasil didaftarkan! Potongan perdana Rp 125.000 akan diproses saat Payroll.'
                          : '❌ Gagal: ${widget.coopService.lastLoginError ?? "NIK sudah terdaftar!"}',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
              child: const Text('Daftarkan'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Data Anggota & Konfirmasi Hapus (PIN Karyawan Terenkripsi & Tidak Bisa Dilihat Admin!)
  void _showEditMemberDialog(BuildContext context, MemberModel member) {
    final nikCtrl = TextEditingController(text: member.nik);
    final nameCtrl = TextEditingController(text: member.name);
    final deptCtrl = TextEditingController(text: member.department);
    final bankCtrl = TextEditingController(text: member.bankName);
    final rekCtrl = TextEditingController(text: member.bankAccountNumber);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Data: ${member.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nikCtrl, decoration: const InputDecoration(labelText: 'NIK Karyawan')),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
              TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Departemen')),
              TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'Nama Bank')),
              TextField(controller: rekCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nomor Rekening')),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.pastelGreenBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_person_rounded, color: AppTheme.successGreen, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PIN Keamanan: •••••• (Terenkripsi)\nAdmin tidak dapat melihat PIN rahasia karyawan. Jika karyawan lupa PIN, karyawan dapat meresetnya sendiri lewat menu "Lupa PIN?" di halaman Login aplikasi.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textDark, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Tombol Hapus Karyawan dengan Dialog Konfirmasi (#91)
          TextButton(
            onPressed: () {
              showDialog(
                context: ctx,
                builder: (confirmCtx) => AlertDialog(
                  title: const Text('Konfirmasi Hapus Karyawan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  content: Text('Apakah Anda yakin ingin menghapus data ${member.name} secara permanen?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text('Batal')),
                    ElevatedButton(
                      onPressed: () {
                        final deleted = widget.coopService.deleteMember(member.id);
                        Navigator.pop(confirmCtx);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              deleted
                                  ? 'Data ${member.name} telah dihapus.'
                                  : '⚠️ Tidak dapat menghapus anggota terakhir!',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
                      child: const Text('Ya, Hapus'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Hapus Anggota', style: TextStyle(color: AppTheme.dangerRed)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final ok = widget.coopService.updateMember(
                memberId: member.id,
                nik: nikCtrl.text,
                name: nameCtrl.text,
                department: deptCtrl.text,
                bankName: bankCtrl.text,
                bankAccountNumber: rekCtrl.text,
                securityPin: member.securityPin, // Pertahankan PIN asli milik karyawan tanpa dilihat Admin
              );
              if (ok) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Data karyawan berhasil diperbarui!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Gagal: NIK sudah digunakan oleh karyawan lain!'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
