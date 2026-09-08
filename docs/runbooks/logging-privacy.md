# Безопасные production-логи

Этот документ определяет минимальный контракт логирования Expatlio для
Firebase/Google Cloud Logging и Crashlytics. Он не разрешает записывать
чувствительные данные даже при временной диагностике инцидента.

## Что разрешено

- фиксированный код события, компонента, результата и ошибки;
- числовые счётчики, HTTP/provider status и безопасные boolean-флаги;
- хеш идентификатора для корреляции, но не исходный идентификатор;
- stack trace только через контролируемый reporter без исходного payload.

Session correlation на клиенте и сервере вычисляется одинаково:
`trim(sessionId)` → UTF-8 → полный lowercase SHA-256. Для остальных сущностей
backend использует отдельный namespaced SHA-256 и короткий digest, чтобы их
нельзя было ошибочно сопоставить с session hash.

## Что запрещено

Нельзя писать email, имя/аватар, токены, authorization headers, URL/имя Daily
комнаты, Firebase/RevenueCat/Resend/Deepgram response body, текст исключения,
caption/transcript/chat, полный request/response или push payload. Произвольная
строка не может становиться именем события или error code.

События deployed backend runtime проходят через `safe_log.js`: неизвестные поля отбрасываются,
идентификаторы хешируются, а сообщения исключений не записываются. Критические
call/auth/payment/AI пути не должны использовать `console.*` напрямую.
Локальные административные CLI из `scripts/` не попадают в Cloud Functions;
их stdout не копируют в issue/чат и не запускают с выводом секретных payload.

## Доступ

- обычная диагностика: только назначенная support/reliability-группа с
  `roles/logging.viewer`;
- private/data-access logs: только incident-response владельцы и только при
  необходимости через `roles/logging.privateLogViewer`;
- изменение buckets/sinks/retention: только platform owner с отдельной
  административной ролью;
- не выдавать широкие Owner/Editor роли только ради просмотра логов;
- доступ пересматривать после изменения команды и не реже одного раза в квартал.

Официальная модель доступа: [Cloud Logging access control](https://cloud.google.com/logging/docs/access-control).

## Retention

Application logs остаются в project `_Default` bucket с целью **30 дней**.
Не создавать sink/export или bucket с большим сроком без записанной причины,
владельца и даты удаления. `_Required` содержит audit logs и управляется
платформой; его срок нельзя считать сроком хранения application payload.

Перед production release platform owner проверяет в Google Cloud Console:
Logging → Log Storage → `_Default` → retention = 30 days, затем сохраняет дату
проверки в release evidence. На машине автора `gcloud` отсутствовал, поэтому
состояние проекта 08.09.2026 локально не подтверждалось и не заявляется как
изменённое. Официальные значения по умолчанию и пределы описаны в
[Cloud Logging quotas and limits](https://cloud.google.com/logging/quotas).

## Инцидент с PII

1. Остановить новый источник записи и зафиксировать только код события/период.
2. Ограничить IAM доступ к затронутым log views/buckets.
3. Удалить или сократить retention допустимым механизмом Cloud Logging; не
   копировать содержимое логов в issue или чат.
4. Проверить соседние события тем же санитизатором и добавить один regression
   test на реальную утечку.
5. Зафиксировать причину, владельца и подтверждение прекращения утечки без
   включения самих чувствительных значений.

## Проверка перед релизом

1. `safe_log.test.js` подтверждает redaction и совместимый session hash.
2. Backend lint и профильные call/auth/payment/AI тесты зелёные.
3. Поиск в критических backend-файлах не находит прямой `console.*`.
4. В Logs Explorer проверить одно тестовое событие: есть `source`, `event` и
   hash; нет исходного ID, URL комнаты, token/email/transcript/provider body.
5. Проверить IAM и 30-дневный retention по разделам выше.
