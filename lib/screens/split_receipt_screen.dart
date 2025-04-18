import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../providers/order_provider.dart';

class SplitReceiptScreen extends StatelessWidget {
  const SplitReceiptScreen({super.key});

  void _showGigaChatDialog(BuildContext context) {
    final items = Provider.of<ReceiptProvider>(context, listen: false).receiptItems;
    final total = items.fold(0.0, (sum, item) => sum + item.total);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GigaChat рекомендует'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ИИ проанализировал ваш чек и предлагает:'),
            const SizedBox(height: 16),
            for (var item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text('• ${item.name}: ${item.total.toStringAsFixed(2)} руб.'),
              ),
            const Divider(),
            Text(
              'Общая сумма: ${total.toStringAsFixed(2)} руб.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'GigaChat советует разделить поровну',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Здесь будет вызов API GigaChat в будущем
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Запрос к GigaChat отправлен')),
              );
            },
            child: const Text('Принять рекомендацию'),
          ),
        ],
      ),
    );
  }

  String _generateReceiptJson(BuildContext context) {
    final provider = Provider.of<ReceiptProvider>(context, listen: false);
    final items = provider.receiptItems;
    
    final receiptData = {
      'items': items.map((item) => {
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
      }).toList(),
      'total': items.fold(0.0, (sum, item) => sum + item.total),
      'date': DateTime.now().toIso8601String(),
    };
    
    return jsonEncode(receiptData);
  }

  Future<void> _shareReceipt(BuildContext context) async {
    final receiptJson = _generateReceiptJson(context);
    final receiptString = base64Url.encode(utf8.encode(receiptJson));
    final shareLink = 'sbersplit://receipt/$receiptString';

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 300,
            maxHeight: 400,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Поделиться чеком',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                  ),
                  child: QrImageView(
                    data: shareLink,
                    version: QrVersions.auto,
                    size: 200,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  shareLink,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Закрыть'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Share.share(
                          'Привет! Вот мой чек для разделения: $shareLink',
                          subject: 'Чек SberSplit',
                        );
                      },
                      child: const Text('Поделиться'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReceiptProvider>(context);
    final items = provider.receiptItems;
    final total = items.fold(0.0, (sum, item) => sum + item.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Разделить чек')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Итого:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${total.toStringAsFixed(2)} руб.',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text('${item.name} (x${item.quantity})'),
                  subtitle: Text('${item.price.toStringAsFixed(2)} руб. × ${item.quantity}'),
                  trailing: Text(
                    '${item.total.toStringAsFixed(2)} руб.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      provider.setAdmin(true);
                      Navigator.pushNamed(
                        context,
                        '/sensor',
                        arguments: {'equalSplit': true},
                      );
                    },
                    child: const Text('Разделить поровну'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      provider.setAdmin(true);
                      Navigator.pushNamed(
                        context,
                        '/sensor',
                        arguments: {'equalSplit': false},
                      );
                    },
                    child: const Text('Разделить выборочно'),
                  ),
                ),                
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showGigaChatDialog(context),
                    style: ElevatedButton.styleFrom(
                      //backgroundColor: Colors.green, 
                    ),
                    child: const Text(
                      'Довериться GigaChat',
                      //style: TextStyle(color: Colors.dark),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _shareReceipt(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text(
                      'Поделиться чеком',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}