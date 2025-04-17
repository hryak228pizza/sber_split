import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import 'bump.dart';

class SplitReceiptScreen extends StatelessWidget {
  const SplitReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReceiptProvider>(context);
    final items = provider.receiptItems;
    final total = items.fold(0.0, (sum, item) => sum + item.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Разделить чек')),
      body: Column(
        children: [
          // Итоговая стоимость
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

          // Список позиций
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

          // Кнопки разделения
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      provider.setAdmin(true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SensorPage(),
                          settings: RouteSettings(arguments: {'equalSplit': true}),
                        ),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SensorPage(),
                          settings: RouteSettings(arguments: {'equalSplit': false}),
                        ),
                      );
                    },
                    child: const Text('Разделить выборочно'),
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