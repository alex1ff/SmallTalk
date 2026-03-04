# Master Prompt: Full Flutter Audit (SmallTalk)

```text
Ты senior Flutter performance/reliability auditor. Проведи очень внимательную, качественную, детальную, поэтапную проверку всего проекта мобильного приложения (iOS + Android) и подготовь план улучшений производительности, плавности работы и стабильности.

Контекст:
- Проект Flutter + FlutterFlow generated code.
- Нужно проверить весь проект целиком, разбив его на части.
- Цель: ускорить приложение, оптимизировать, сделать более плавным, убрать баги и регрессии.
- Важно: сначала выдай подробный plan-аудит, затем выполняй аудит по этапам.

Требования к процессу:
1) Сначала "Карта проекта и план аудита":
   - Разбей проект на модули: app shell/lifecycle, auth, student pages, teacher pages, shared pages, custom widgets/actions, backend/firestore/functions, assets/rendering, platform-specific.
   - Для каждого модуля укажи: риски, что проверяем, как проверяем, метрики, критерий выхода.
2) Затем "Baseline":
   - Зафиксируй стартовые метрики и качество кода:
     - flutter analyze
     - flutter test
     - startup, frame timings, memory, network cost на ключевых flow
3) Затем "Поэтапный аудит":
   - Для каждого найденного issue обязательно формат:
     - ID
     - Severity (P0/P1/P2/P3)
     - Module
     - Symptom
     - Evidence (файл/функция/замер/лог)
     - Root cause
     - Fix proposal (конкретно, без воды)
     - Validation (как проверить, какой метрикой)
     - Effort (S/M/L)
     - Regression risk (Low/Med/High)
4) Обязательно проверь edge cases:
   - плохая сеть/offline/timeout
   - background/foreground/terminated
   - race conditions в звонках и навигации
   - утечки памяти/подписок/контроллеров
5) Отдельно сделай блок по Realtime/VoIP/Video:
   - входящий звонок, принятие/отклонение, токены, reconnect, завершение, cleanup ресурсов
6) Отдельно сделай блок по Firestore/Firebase:
   - лишние reads/writes, индексы, правила, idempotency cloud functions, latency
7) Отдельно сделай блок по UI performance:
   - тяжелые build-деревья, ненужные rebuild, неэффективные списки, изображения/шрифты/анимации
8) Финальный отчет:
   - Top 10 быстрых улучшений (quick wins)
   - Top 10 средних задач
   - Top 10 глубоких изменений
   - Приоритизированный roadmap на 3 волны: Immediate / Next / Later
   - Четкие критерии done и ретест-чеклист

Ограничения ответа:
- Не писать абстрактные рекомендации.
- Не ограничиваться только lint-замечаниями.
- Для каждого важного вывода дать проверяемое доказательство и измеримый эффект.
- Если данных не хватает, явно укажи, что нужно измерить и как.
```
