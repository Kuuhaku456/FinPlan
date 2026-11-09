import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../data/transaction_repository.dart';
import '../../../../services/transaction_csv_export_service.dart';

import 'settings_components.dart';

// ==========================================
// FINPLAN - TRANSACTION EXPORT CARD
// ==========================================

const Color _finPlanGreen = Color(0xFF064E3B);

const List<String> _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

// ==========================================
// STATE
// ==========================================

class _ExportUiState {
  const _ExportUiState({
    required this.selectedMonth,
    this.exportAll = false,
    this.isBusy = false,
    this.isSharing = false,
    this.result,
    this.error,
  });

  final DateTime selectedMonth;
  final bool exportAll;
  final bool isBusy;
  final bool isSharing;

  final CsvExportResult? result;
  final String? error;
}

// ==========================================
// MAIN WIDGET
// ==========================================

class TransactionExportCard extends StatefulWidget {
  const TransactionExportCard({
    super.key,
  });

  @override
  State<TransactionExportCard> createState() =>
      _TransactionExportCardState();
}

class _TransactionExportCardState
    extends State<TransactionExportCard> {

  // Repository dan service menggunakan
  // database transaksi FinPlan yang sama.
  final TransactionRepository _repository =
      TransactionRepository();

  late final TransactionCsvExportService _exportService =
      TransactionCsvExportService(_repository);

  // State UI menggunakan ValueNotifier.
  // Tidak perlu setState().
  late final ValueNotifier<_ExportUiState> _ui =
      ValueNotifier<_ExportUiState>(
    _ExportUiState(
      selectedMonth: DateTime(
        DateTime.now().year,
        DateTime.now().month,
      ),
    ),
  );

  final NumberFormat _currency =
      NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  // ========================================
  // FORMAT
  // ========================================

  String _formatRupiah(int amount) {
    return _currency.format(amount);
  }

  String _formatMonth(DateTime month) {
    return '${_monthNames[month.month - 1]} ${month.year}';
  }

  // ========================================
  // CHANGE EXPORT SCOPE
  // ========================================

  void _changeExportScope(bool exportAll) {
    final current = _ui.value;

    if (current.isBusy || current.isSharing) {
      return;
    }

    _ui.value = _ExportUiState(
      selectedMonth: current.selectedMonth,
      exportAll: exportAll,
    );
  }

  // ========================================
  // CHANGE MONTH
  // ========================================

  void _changeMonth(int direction) {
    final current = _ui.value;

    if (current.isBusy || current.isSharing) {
      return;
    }

    final newMonth = DateTime(
      current.selectedMonth.year,
      current.selectedMonth.month + direction,
    );

    _ui.value = _ExportUiState(
      selectedMonth: newMonth,
      exportAll: false,
    );
  }

  // ========================================
  // PREPARE CSV
  // ========================================

  Future<void> _prepareExport() async {
    final current = _ui.value;

    if (current.isBusy || current.isSharing) {
      return;
    }

    _ui.value = _ExportUiState(
      selectedMonth: current.selectedMonth,
      exportAll: current.exportAll,
      isBusy: true,
    );

    try {
      DateTime? startDate;
      DateTime? endDate;

      if (!current.exportAll) {
        startDate = DateTime(
          current.selectedMonth.year,
          current.selectedMonth.month,
          1,
        );

        endDate = DateTime(
          current.selectedMonth.year,
          current.selectedMonth.month + 1,
          0,
        );
      }

      final result =
          await _exportService.exportTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) {
        return;
      }

      _ui.value = _ExportUiState(
        selectedMonth: current.selectedMonth,
        exportAll: current.exportAll,
        result: result,
      );

    } catch (error) {
      if (!mounted) {
        return;
      }

      _ui.value = _ExportUiState(
        selectedMonth: current.selectedMonth,
        exportAll: current.exportAll,
        error:
            'Gagal menyiapkan file CSV. Silakan coba lagi.',
      );
    }
  }

  // ========================================
  // SHARE CSV
  // ========================================

  Future<void> _shareCsv(BuildContext buttonContext) async {
    final current = _ui.value;
    final result = current.result;

    if (result == null ||
        current.isBusy ||
        current.isSharing) {
      return;
    }

    _ui.value = _ExportUiState(
      selectedMonth: current.selectedMonth,
      exportAll: current.exportAll,
      result: result,
      isSharing: true,
    );

    try {
      final exists = await result.file.exists();

      if (!exists) {
        throw StateError(
          'File CSV tidak ditemukan.',
        );
      }

      if (!mounted || !buttonContext.mounted) {
        return;
      }

      // Posisi diperlukan untuk dialog share
      // di iPad serta perangkat tertentu.
      final renderBox =
          buttonContext.findRenderObject()
              as RenderBox?;

      final Rect? shareOrigin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) &
              renderBox.size;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              result.file.path,
              mimeType: 'text/csv',
            ),
          ],
          title: 'FinPlan - Export Transaksi',
          subject: 'Riwayat Transaksi FinPlan',
          sharePositionOrigin: shareOrigin,
        ),
      );

      if (!mounted) {
        return;
      }

      _ui.value = _ExportUiState(
        selectedMonth: current.selectedMonth,
        exportAll: current.exportAll,
        result: result,
      );

    } catch (error) {
      if (!mounted) {
        return;
      }

      _ui.value = _ExportUiState(
        selectedMonth: current.selectedMonth,
        exportAll: current.exportAll,
        result: result,
        error:
            'Gagal membuka menu berbagi. '
            'Coba buat ulang file CSV.',
      );
    }
  }

  // ========================================
  // BUILD SCOPE BUTTON
  // ========================================

  Widget _scopeButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 18,
        ),
        label: Text(
          title,
          textAlign: TextAlign.center,
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? _finPlanGreen.withValues(alpha: 0.10)
              : null,
          foregroundColor: selected
              ? _finPlanGreen
              : null,
          side: BorderSide(
            color: selected
                ? _finPlanGreen
                : Theme.of(context)
                    .colorScheme
                    .outlineVariant,
            width: selected ? 1.8 : 1,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ========================================
  // BUILD MONTH SELECTOR
  // ========================================

  Widget _buildMonthSelector(
    _ExportUiState state,
  ) {
    final disabled = state.isBusy || state.isSharing;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: disabled
                ? null
                : () => _changeMonth(-1),
            icon: const Icon(
              Icons.chevron_left_rounded,
            ),
          ),

          Expanded(
            child: Text(
              _formatMonth(state.selectedMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: disabled
                ? null
                : () => _changeMonth(1),
            icon: const Icon(
              Icons.chevron_right_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // BUILD SUMMARY ITEM
  // ========================================

  Widget _summaryItem({
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
            size: 20,
            color: color,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // BUILD EXPORT RESULT
  // ========================================

  Widget _buildExportResult(
    _ExportUiState state,
    CsvExportResult result,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.primary
              .withValues(alpha: 0.22),
        ),
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

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'File CSV Siap',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            result.fileName,
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),

          const SizedBox(height: 12),

          _summaryItem(
            label: 'Jumlah Transaksi',
            value: '${result.transactionCount}',
            icon: Icons.receipt_long_rounded,
            color: scheme.onSurface,
          ),

          _summaryItem(
            label: 'Total Pemasukan',
            value: _formatRupiah(
              result.totalIncome,
            ),
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF059669),
          ),

          _summaryItem(
            label: 'Total Pengeluaran',
            value: _formatRupiah(
              result.totalExpense,
            ),
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFDC2626),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (buttonContext) {
                return FilledButton.icon(
                  onPressed: state.isSharing ||
                          state.isBusy ||
                          result.transactionCount == 0
                      ? null
                      : () => _shareCsv(buttonContext),
                  icon: state.isSharing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.ios_share_rounded,
                        ),
                  label: Text(
                    state.isSharing
                        ? 'Membuka menu berbagi...'
                        : 'Bagikan / Simpan CSV',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _finPlanGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                );
              },
            ),
          ),

          if (result.transactionCount == 0)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Tidak ada transaksi pada periode ini.',
              ),
            ),
        ],
      ),
    );
  }

  // ========================================
  // MAIN BUILD
  // ========================================

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<_ExportUiState>(
      valueListenable: _ui,
      builder: (context, state, _) {
        final disabled =
            state.isBusy || state.isSharing;

        return SettingsSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  SettingsIconBox(
                    icon: Icons.file_download_outlined,
                    color: scheme.primary,
                    background:
                        scheme.primaryContainer,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Transaksi',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Simpan riwayat keuangan '
                          'dalam format CSV untuk '
                          'Excel atau Google Sheets.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                'Pilih Periode',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  _scopeButton(
                    title: 'Per Bulan',
                    icon: Icons.calendar_month_rounded,
                    selected: !state.exportAll,
                    onTap: disabled
                        ? null
                        : () => _changeExportScope(false),
                  ),

                  const SizedBox(width: 10),

                  _scopeButton(
                    title: 'Semua',
                    icon: Icons.all_inbox_rounded,
                    selected: state.exportAll,
                    onTap: disabled
                        ? null
                        : () => _changeExportScope(true),
                  ),
                ],
              ),

              if (!state.exportAll) ...[
                const SizedBox(height: 14),
                _buildMonthSelector(state),
              ],

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: disabled || kIsWeb
                      ? null
                      : _prepareExport,

                  icon: state.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.description_outlined,
                        ),

                  label: Text(
                    state.isBusy
                        ? 'Menyiapkan CSV...'
                        : 'Buat CSV',
                  ),

                  style: FilledButton.styleFrom(
                    backgroundColor: _finPlanGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                  ),
                ),
              ),

              if (kIsWeb) ...[
                const SizedBox(height: 10),
                Text(
                  'Ekspor CSV saat ini tersedia '
                  'di aplikasi HP.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],

              if (state.error != null) ...[
                const SizedBox(height: 12),

                Text(
                  state.error!,
                  style: TextStyle(
                    color: scheme.error,
                  ),
                ),
              ],

              if (state.result != null) ...[
                const SizedBox(height: 16),

                _buildExportResult(
                  state,
                  state.result!,
                ),
              ],

              const SizedBox(height: 10),

              Text(
                'File dibuat dari transaksi yang '
                'tersimpan di perangkatmu. '
                'Simpan salinannya melalui menu berbagi '
                'agar tidak hanya berada di penyimpanan sementara.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
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