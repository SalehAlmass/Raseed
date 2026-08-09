import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/desktop_tokens.dart';

/// Desktop data table rendered as a bordered card with a sticky header,
/// optional row striping and vertical scrolling above [maxHeight].
class DesktopTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final List<int>? flexes;
  final String? emptyMessage;
  final bool isLoading;
  final double? maxHeight;

  const DesktopTable({
    super.key,
    required this.headers,
    required this.rows,
    this.flexes,
    this.emptyMessage,
    this.isLoading = false,
    this.maxHeight = 420,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final effectiveFlexes = flexes ??
        List<int>.filled(headers.length, 1, growable: false);
    final widthMap = <int, TableColumnWidth>{
      for (var i = 0; i < headers.length; i++)
        i: FlexColumnWidth(effectiveFlexes[i].toDouble()),
    };

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderRow(colors, widthMap),
          const Divider(height: 1),
          if (isLoading)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  emptyMessage ?? 'no_transactions'.tr(),
                  style: TextStyle(color: colors.textLight),
                ),
              ),
            )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight ?? 420),
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: widthMap,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      for (var r = 0; r < rows.length; r++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: r.isEven
                                ? colors.surface
                                : colors.surfaceContainer.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                          children: [
                            for (final cell in rows[r])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.sm,
                                  vertical: AppSpace.sm,
                                ),
                                child: cell,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(AppColorSet colors, Map<int, TableColumnWidth> widths) {
    return Container(
      color: colors.primary.withValues(alpha: 0.06),
      child: Table(
        columnWidths: widths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              for (final header in headers)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.sm,
                  ),
                  child: Text(
                    header,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
