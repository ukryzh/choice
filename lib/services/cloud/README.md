# Cloud Storage Service API

## Обзор

Реализована система облачной синхронизации с шифрованием данных для будущей интеграции с Firebase. Каждая запись шифруется отдельно перед отправкой в облако.

## Структура

### 1. EncryptionService (`encryption_service.dart`)
Сервис для шифрования отдельных записей:
- Каждая запись шифруется независимо с использованием AES-256-CBC + HMAC
- Ключ шифрования хранится в FlutterSecureStorage
- Методы: `encryptRecord()`, `decryptRecord()`

**Важно:** Текущая реализация использует упрощённый алгоритм. Для production необходимо заменить на настоящий AES-256-GCM (например, используя библиотеку `pointycastle`).

### 2. CloudStorageService (`cloud_storage_service.dart`)
Абстрактный интерфейс для облачного хранилища:
- `uploadRecord()` - загрузка зашифрованной записи
- `downloadRecord()` - скачивание зашифрованной записи
- `downloadAllRecords()` - скачивание всех записей типа
- `deleteRecord()` - удаление записи
- `enableSync()` / `disableSync()` - управление синхронизацией
- `syncAll()` / `syncChanges()` - синхронизация данных

### 3. FirebaseCloudStorageService (`firebase_cloud_storage_service.dart`)
Заглушка для будущей интеграции с Firebase:
- Реализует интерфейс `CloudStorageService`
- Все методы помечены TODO для реализации Firebase Firestore
- Готова к замене на реальную реализацию

## Что такое "запись"?

Запись - это отдельная сущность с уникальным ID:
- **CycleEntry** - одна запись о менструальном цикле (id, cycleStart, cycleEnd, symptoms, createdAt)
- **Transaction** - одна транзакция (id, type, date, и другие поля)

Каждая запись шифруется отдельно перед отправкой в облако.

## Интеграция

### В репозиториях
`CycleRepository` автоматически синхронизирует записи с облаком при сохранении/удалении, если синхронизация включена.

### В UI
- При входе через Google показывается диалог предложения включить облачную синхронизацию
- В Profile есть переключатель для включения/выключения синхронизации

## Следующие шаги для интеграции Firebase

1. Добавить зависимости Firebase в `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^latest
  cloud_firestore: ^latest
```

2. Реализовать методы в `FirebaseCloudStorageService`:
   - Заменить TODO комментарии на реальный код Firebase Firestore
   - Использовать структуру: `users/{userId}/records/{recordType}/data/{recordId}`

3. Улучшить шифрование:
   - Добавить `pointycastle` в зависимости
   - Заменить упрощённый алгоритм на AES-256-GCM

4. Инициализировать Firebase в `main.dart`:
```dart
await Firebase.initializeApp();
```

5. Получить userId из Firebase Auth для использования в путях Firestore

## Безопасность

- Каждая запись шифруется отдельно
- Ключ шифрования хранится локально в FlutterSecureStorage
- Данные в облаке хранятся в зашифрованном виде
- Даже при компрометации облачного хранилища данные остаются защищёнными






