import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/transaction_repository.dart';
import '../../../../services/transaction_csv_import_service.dart';
import '../../../../state/transaction_notifier.dart';

import 'settings_components.dart';

// ==========================================
// FINPLAN - TRANSACTION IMPORT CARD
// ==========================================

const Color _finPlanGreen = Color(0xFF064E3B);

// ==========================================
// UI STATE
// ==========================================

class _ImportUiState {
  const _ImportUiState({
    this.fileName,
    this.csvText,
    this.preview,
    this.result,
    this.isSelecting = false,
    this.isImporting = false,
    this.error,
  });

  final String? fileName;
  final String? csvText;

  final CsvImportPreview? preview;
  final CsvImportResult? result;

  final bool isSelecting;
  final bool isImporting;

  final String? error;

  bool get isBusy => isSelecting || isImporting;
}

// ==========================================
// MAIN WIDGET
// ==========================================

class TransactionImportCard
    extends ConsumerStatefulWidget {
  const TransactionImportCard({
    super.key,
  });

  @override
  ConsumerState<TransactionImportCard> createState() =>
      _TransactionImportCardState();
}

class _TransactionImportCardState
    extends ConsumerState<TransactionImportCard> {

  final TransactionRepository _repository =
      TransactionRepository();

  late final TransactionCsvImportService _importService =
      TransactionCsvImportService(_repository);

  // Menggunakan ValueNotifier.
  // Tidak memerlukan setState().
  final ValueNotifier<_ImportUiState> _ui =
      ValueNotifier<_ImportUiState>(
    const _ImportUiState(),
  );

  // Batas file CSV: 15 MB.
  static const int _maxFileSize =
      15 * 1024 * 1024;

  // ========================================
  // FORMAT ERROR
  // ========================================

  String _errorMessage(Object error) {
    if (error is FormatException) {
      return error.message;
    }

    return 'Terjadi kesalahan saat membaca '
        'atau memproses file CSV.';
  }

  // ========================================
  // 1. MEMILIH FILE CSV
  // ========================================

  Future<void> _pickCsvFile() async {
    if (_ui.value.isBusy) {
      return;
    }

    final previousState = _ui.value;

    _ui.value = const _ImportUiState(
      isSelecting: true,
    );

    try {
      // FileType.any digunakan agar file CSV
      // dari Files, Downloads, atau cloud
      // dapat dipilih pada berbagai HP.
      //
      // Ekstensi tetap divalidasi setelah
      // pengguna memilih file.
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (!mounted) {
        return;
      }

      // Pengguna menutup pemilih file.
      if (picked == null || picked.files.isEmpty) {
        _ui.value = previousState;
        return;
      }

      final file = picked.files.single;

      // ====================================
      // VALIDASI EKSTENSI
      // ====================================

      if (!file.name.toLowerCase().endsWith('.csv')) {
        throw const FormatException(
          'Pilih file dengan ekstensi .csv.',
        );
      }

      // ====================================
      // VALIDASI UKURAN
      // ====================================

      if (file.size > _maxFileSize) {
        throw const FormatException(
          'Ukuran file terlalu besar. '
          'Maksimal 15 MB.',
        );
      }

      // ====================================
      // MEMBACA DATA
      // ====================================

      final bytes = file.bytes;

      if (bytes == null) {
        throw const FormatException(
          'Isi file tidak dapat dibaca. '
          'Coba pilih file dari penyimpanan HP.',
        );
      }

      final csvText = utf8.decode(
        bytes,
        allowMalformed: false,
      );

      // ====================================
      // PREVIEW TANPA MENYIMPAN
      // ====================================

      final preview =
          await _importService.previewCsv(
        csvText,
      );

      if (!mounted) {
        return;
      }

      _ui.value = _ImportUiState(
        fileName: file.name,
        csvText: csvText,
        preview: preview,
      );

    } catch (error) {
      if (!mounted) {
        return;
      }

      _ui.value = _ImportUiState(
        error: _errorMessage(error),
      );
    }
  }

  // ========================================
  // 2. KONFIRMASI IMPORT
  // ========================================

  Future<void> _confirmImport() async {
    final current = _ui.value;

    if (current.isBusy ||
        current.preview == null ||
        current.csvText == null ||
        !current.preview!.canImport) {
      return;
    }

    final preview = current.preview!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Konfirmasi Import Transaksi',
          ),
          content: Text(
            'FinPlan akan menambahkan '
            '${preview.importableRows} transaksi baru.\n\n'
            '${preview.duplicateRows} transaksi identik '
            'akan dilewati.\n\n'
            'Transaksi yang sudah tersimpan '
            'tidak akan dihapus atau ditimpa.\n\n'
            'Lanjutkan proses import?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _finPlanGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Ya, Import'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await _executeImport(current);
  }

  // ========================================
  // 3. MENJALANKAN IMPORT
  // ========================================

  Future<void> _executeImport(
    _ImportUiState previousState,
  ) async {
    final csvText = previousState.csvText;

    if (csvText == null) {
      return;
    }

    _ui.value = _ImportUiState(
      fileName: previousState.fileName,
      csvText: csvText,
      preview: previousState.preview,
      isImporting: true,
    );

    try {
      final result =
          await _importService.importCsv(
        csvText,
      );

      if (!mounted) {
        return;
      }

      // Hasil disimpan terlebih dahulu agar
      // keberhasilan import tidak disalahartikan
      // sebagai kegagalan jika refresh UI bermasalah.
      _ui.value = _ImportUiState(
        fileName: previousState.fileName,
        preview: previousState.preview,
        result: result,
      );

      // Memperbarui state transaksi.
      try {
        await ref
            .read(transactionStateProvider.notifier)
            .refresh();
      } catch (_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Data berhasil diimport, tetapi '
              'tampilan transaksi belum diperbarui. '
              'Coba buka kembali halaman Transaksi.',
            ),
          ),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _finPlanGreen,
          content: Text(
            '${result.importedRows} transaksi '
            'berhasil ditambahkan.',
          ),
        ),
      );

    } catch (error) {
      if (!mounted) {
        return;
      }

      _ui.value = _ImportUiState(
        fileName: previousState.fileName,
        csvText: csvText,
        preview: previousState.preview,
        error: _errorMessage(error),
      );
    }
  }

  // ========================================
  // 4. MEMBATALKAN PILIHAN FILE
  // ========================================

  void _resetSelection() {
    if (_ui.value.isBusy) {
      return;
    }

    _ui.value = const _ImportUiState();
  }

  // ========================================
  // 5. SUMMARY ROW
  // ========================================

  Widget _summaryRow({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(label),
          ),

          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // 6. PREVIEW CARD
  // ========================================

  Widget _buildPreview(
    _ImportUiState state,
    CsvImportPreview preview,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer
            .withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.primary
              .withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: scheme.primary,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Pratinjau Import',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            state.fileName ?? 'File CSV',
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),

          const SizedBox(height: 12),

          _summaryRow(
            label: 'Jumlah Transaksi',
            value: '${preview.totalRows}',
            icon: Icons.receipt_long_rounded,
            color: scheme.onSurface,
          ),

          _summaryRow(
            label: 'Transaksi Baru',
            value: '${preview.importableRows}',
            icon: Icons.add_circle_outline_rounded,
            color: const Color(0xFF059669),
          ),

          _summaryRow(
            label: 'Transaksi Identik',
            value: '${preview.duplicateRows}',
            icon: Icons.copy_rounded,
            color: const Color(0xFFD97706),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.isBusy ||
                      state.result != null ||
                      !preview.canImport
                  ? null
                  : _confirmImport,

              icon: state.isImporting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.file_download_done_rounded,
                    ),

              label: Text(
                state.isImporting
                    ? 'Mengimport Transaksi...'
                    : 'Import ${preview.importableRows} Transaksi',
              ),

              style: FilledButton.styleFrom(
                backgroundColor: _finPlanGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
          ),

          if (!preview.canImport &&
              state.result == null) ...[
            const SizedBox(height: 10),

            const Text(
              'Tidak ada transaksi baru yang '
              'perlu diimport.',
            ),
          ],
        ],
      ),
    );
  }

  // ========================================
  // 7. RESULT CARD
  // ========================================

  Widget _buildResult(
    CsvImportResult result,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
              ),

              const SizedBox(width: 9),

              const Expanded(
                child: Text(
                  'Import Selesai',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _summaryRow(
            label: 'Berhasil Ditambahkan',
            value: '${result.importedRows}',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF059669),
          ),

          _summaryRow(
            label: 'Dilewati',
            value: '${result.duplicateRows}',
            icon: Icons.remove_circle_outline_rounded,
            color: const Color(0xFFD97706),
          ),

          const SizedBox(height: 12),

          Text(
            'Riwayat transaksi sudah diproses '
            'dan tersimpan di database FinPlan.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ========================================
  // 8. BUILD
  // ========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ValueListenableBuilder<_ImportUiState>(
      valueListenable: _ui,
      builder: (context, state, _) {
        return SettingsSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================
              // HEADER
              // ==================================

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  SettingsIconBox(
                    icon: Icons.upload_file_rounded,
                    color: scheme.primary,
                    background: scheme.primaryContainer,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Transaksi',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Pulihkan riwayat transaksi '
                          'menggunakan file backup CSV FinPlan.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ==================================
              // PICK FILE BUTTON
              // ==================================

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: state.isBusy || kIsWeb
                      ? null
                      : _pickCsvFile,

                  icon: state.isSelecting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.folder_open_rounded,
                        ),

                  label: Text(
                    state.isSelecting
                        ? 'Membaca File...'
                        : 'Pilih File CSV',
                  ),

                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    side: BorderSide(
                      color: scheme.primary,
                    ),
                    foregroundColor: scheme.primary,
                  ),
                ),
              ),

              if (kIsWeb) ...[
                const SizedBox(height: 10),
                Text(
                  'Import CSV saat ini tersedia '
                  'pada aplikasi HP.',
                  style: theme.textTheme.bodySmall,
                ),
              ],

              // ==================================
              // ERROR MESSAGE
              // ==================================

              if (state.error != null) ...[
                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: scheme.onErrorContainer,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          state.error!,
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ==================================
              // PREVIEW
              // ==================================

              if (state.preview != null) ...[
                const SizedBox(height: 16),

                _buildPreview(
                  state,
                  state.preview!,
                ),
              ],

              // ==================================
              // RESULT
              // ==================================

              if (state.result != null) ...[
                const SizedBox(height: 16),

                _buildResult(
                  state.result!,
                ),
              ],

              // ==================================
              // RESET BUTTON
              // ==================================

              if (state.preview != null ||
                  state.result != null) ...[
                const SizedBox(height: 10),

                TextButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : _resetSelection,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label: const Text(
                    'Pilih File Lain',
                  ),
                ),
              ],

              const SizedBox(height: 10),

              Text(
                'Gunakan file CSV hasil export FinPlan. '
                'Periksa pratinjau sebelum melanjutkan. '
                'Transaksi yang sudah ada tidak akan ditimpa.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ========================================
  // DISPOSE
  // ========================================

  @override
  void dispose() {
    _ui.dispose();
    super.dispose();
  }
}