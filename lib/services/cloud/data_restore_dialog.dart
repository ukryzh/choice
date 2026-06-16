import 'package:flutter/material.dart';

/// Dialog to ask user if they want to restore data from cloud
/// Shows after successful authentication when cloud data is detected
Future<bool> showDataRestoreDialog(
  BuildContext context, {
  required int entryCount,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Восстановить данные из облака?'),
      content: Text(
        'Мы нашли $entryCount ${entryCount == 1 ? 'запись' : entryCount < 5 ? 'записи' : 'записей'} в вашей облачной резервной копии. Хотите восстановить их на это устройство?\n\n'
        'Ваши текущие локальные данные будут сохранены и объединены с данными из облака.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Не сейчас'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Восстановить'),
        ),
      ],
    ),
  );

  return result ?? false;
}


