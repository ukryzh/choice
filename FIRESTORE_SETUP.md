# Настройка Firestore Database для синхронизации данных

## Структура коллекций

Firestore использует следующую структуру для хранения зашифрованных данных пользователей:

```
users/
  {userId}/
    records/
      {recordType}/
        data/
          {recordId}/
            encryptedData: string (base64)
            timestamp: timestamp
            recordType: string
            updatedAt: timestamp (server timestamp)
```

### Пример структуры:

```
users/
  abc123/
    records/
      cycle_entry/
        data/
          entry-001/
            encryptedData: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
            timestamp: 2025-01-15T10:30:00Z
            recordType: "cycle_entry"
            updatedAt: 2025-01-15T10:30:00Z
          entry-002/
            ...
      transaction/
        data/
          trans-001/
            encryptedData: "..."
            timestamp: 2025-01-15T11:00:00Z
            recordType: "transaction"
            updatedAt: 2025-01-15T11:00:00Z
```

## Типы записей (recordType)

- `cycle_entry` - записи о менструальном цикле
- `transaction` - транзакции пользователя

## Настройка Firestore в Firebase Console

### 1. Создание базы данных

1. Откройте [Firebase Console](https://console.firebase.google.com/)
2. Выберите ваш проект
3. Перейдите в раздел **Firestore Database**
4. Нажмите **Create database**
5. Выберите режим:
   - **Production mode** (рекомендуется для продакшена)
   - **Test mode** (для разработки, автоматически разрешает доступ на 30 дней)
6. Выберите регион для базы данных (ближайший к вашим пользователям)

### 2. Правила безопасности (Security Rules)

Перейдите в раздел **Rules** и установите следующие правила:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }
    
    // Users collection - each user can only access their own data
    match /users/{userId} {
      // Allow read/write only if user is authenticated and owns the data
      allow read, write: if isOwner(userId);
      
      // Records subcollection
      match /records/{recordType} {
        // Allow read/write only if user owns the data
        allow read, write: if isOwner(userId);
        
        // Data subcollection - encrypted records
        match /data/{recordId} {
          // Allow read/write only if user owns the data
          allow read, write: if isOwner(userId);
        }
      }
    }
    
    // User emails collection - for email to userId mapping
    // Users can read their own email mapping and write their own
    match /user_emails/{emailDocId} {
      // Allow read if authenticated (to find userId by email)
      // Allow write only if the userId in the document matches the authenticated user
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() && 
        (request.resource.data.userId == request.auth.uid || 
         resource == null); // Allow create if document doesn't exist
    }
  }
}
```

### 3. Индексы (Indexes)

Firestore автоматически создаст необходимые индексы. Если вы планируете использовать сложные запросы (например, по timestamp), вы можете создать составные индексы в разделе **Indexes**.

Для текущей реализации индексы не требуются, так как мы используем простые запросы по document ID.

## Безопасность

### Шифрование данных

- Все данные шифруются **перед** отправкой в Firestore
- Ключ шифрования хранится локально на устройстве в `FlutterSecureStorage`
- В Firestore хранятся только зашифрованные данные (base64 строка)
- Даже администраторы Firebase не могут прочитать данные без ключа шифрования

### Правила доступа

- Пользователи могут читать и записывать только свои собственные данные
- Доступ контролируется через Firebase Authentication (userId)
- Правила безопасности проверяются на стороне сервера

## Тестирование

### Проверка структуры данных

1. После первого включения синхронизации, откройте Firestore Console
2. Проверьте, что создалась структура: `users/{userId}/records/{recordType}/data/{recordId}`
3. Убедитесь, что документы содержат поля:
   - `encryptedData` (string)
   - `timestamp` (timestamp)
   - `recordType` (string)
   - `updatedAt` (timestamp)

### Проверка правил безопасности

1. Попробуйте создать тестовый документ с другим userId
2. Правила должны блокировать доступ
3. Проверьте логи в Firebase Console на наличие ошибок доступа

## Мониторинг

### Использование и квоты

- Отслеживайте использование в разделе **Usage** в Firebase Console
- Firestore имеет бесплатный план с ограничениями:
  - 50K чтений в день
  - 20K записей в день
  - 20K удалений в день

### Логи

- Ошибки синхронизации логируются в консоль приложения
- Проверяйте логи в Firebase Console для ошибок правил безопасности

## Резервное копирование

Firestore автоматически создает резервные копии. Вы можете настроить автоматическое резервное копирование в разделе **Backups** (требуется план Blaze).

## Дополнительные настройки

### Регион базы данных

Выберите регион, ближайший к большинству ваших пользователей:
- `us-central` (США)
- `europe-west` (Европа)
- `asia-southeast1` (Азия)

После создания базы данных регион нельзя изменить.

### Режим работы

- **Native mode** - стандартный режим Firestore (рекомендуется)
- **Datastore mode** - режим совместимости (не рекомендуется для новых проектов)

