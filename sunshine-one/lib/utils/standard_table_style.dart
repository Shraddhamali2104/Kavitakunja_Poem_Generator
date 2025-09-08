import 'package:flutter/material.dart';

class CustomTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;

  /// Optional: allow passing custom column widths
  final Map<int, TableColumnWidth>? columnWidths;

  const CustomTable({
    super.key,
    required this.headers,
    required this.rows,
    this.columnWidths,
  });

  @override
  Widget build(BuildContext context) {
    // Use custom widths if provided, else auto-size columns to content
    final widths =
        columnWidths ??
        {
          for (int i = 0; i < headers.length; i++)
            i: const IntrinsicColumnWidth(),
        };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Table(
              columnWidths: widths,
              children: [
                TableRow(
                  children: headers
                      .map((header) => _buildHeaderCell(header))
                      .toList(),
                ),
              ],
            ),
          ),

          // Body Rows
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isLast = index == rows.length - 1;

            return _buildTableRow(row, widths, isLast: isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: child,
    );
  }

  Widget _buildTableRow(
    List<Widget> cells,
    Map<int, TableColumnWidth> widths, {
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Table(
        columnWidths: widths,
        children: [
          TableRow(
            children: cells
                .map(
                  (cell) => TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: _buildTableCell(cell),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
