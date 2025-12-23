import 'package:flutter/material.dart';

class LeaveCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(String) onStatusChange;

  const LeaveCard({
    super.key,
    required this.item,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    // NOTE: No GestureDetector here. Parent handles onTap to open details.
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 3,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...item.entries.where((e) => e.key != 'status').map((e) {
              final key = _formatKey(e.key);
              String value = e.value?.toString() ?? '';
              if (e.key == 'reason' && value.trim().isEmpty) {
                value = '—'; // nicer empty reason
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text("$key: $value"),
              );
            }),
            const SizedBox(height: 10),
            if ((item['status'] ?? '').toString().toLowerCase() == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => onStatusChange('approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 30),
                      textStyle: const TextStyle(fontSize: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Approve"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => onStatusChange('rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 30),
                      textStyle: const TextStyle(fontSize: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Reject"),
                  ),
                ],
              )
            else
              Text(
                "Status: ${_cap((item['status'] ?? '').toString())}",
                style: TextStyle(
                  color: (item['status'] == 'approved')
                      ? Colors.green
                      : (item['status'] == 'rejected')
                          ? Colors.red
                          : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatKey(String key) => key
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .split('_')
      .map(_cap)
      .join(' ');

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
