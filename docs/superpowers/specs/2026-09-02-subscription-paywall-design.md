# Subscription paywall design

## Цель

Пользователь без подписки должен видеть не единственный trial, а два понятных
варианта покупки:

1. один месяц с трёхдневным бесплатным introductory period;
2. три месяца с оплатой сразу.

Экран не подменяет данные магазина: цена, валюта и доступность берутся только
из StoreKit через RevenueCat. Статус `Ready to Submit` достаточен для
TestFlight/Sandbox, но до активации Paid Applications Agreement и банковских и
налоговых данных StoreKit может возвращать пустой каталог.

## Границы

- Меняется только студенческий `PayWidget` и его небольшие UI-компоненты.
- RevenueCat остаётся единственным клиентским purchase gateway.
- Firebase webhook и серверная модель подписки не меняются.
- Product IDs остаются прежними:
  - `expatlio_trial_1_Month` — месяц с introductory trial;
  - `expatlio_1_Month` — обычный месяц для немедленного upgrade во время trial;
  - `expatlio_3_Month` — три месяца с оплатой сразу.
- Локальные или захардкоженные цены не показываются.
- Визуальная переработка ограничена paywall; новый design system не вводится.

## Сценарии и состав тарифов

| Состояние пользователя | Видимые варианты | Выбор по умолчанию |
|---|---|---|
| Нет активной подписки | месяц с 3 днями бесплатно; 3 месяца сразу | месяц с trial |
| Активный trial | обычный месяц сразу; 3 месяца сразу | 3 месяца |
| `premiumOnly=true` | обычный месяц сразу; 3 месяца сразу | 3 месяца |
| Активная платная подписка | обычный месяц; 3 месяца для смены плана | текущий paid product; для renewed trial product — обычный месяц; иначе 3 месяца |

Таким образом, вход из профиля всегда даёт возможность оплатить доступ сразу:
до trial это трёхмесячный продукт, во время trial — оба платных продукта.

Приоритет пересекающихся состояний однозначный:

1. `premiumOnly=true` всегда исключает trial product;
2. активный trial показывает только немедленные paid upgrades;
3. активная платная подписка показывает paid варианты смены плана;
4. только пользователь без активной подписки проходит проверку introductory
   eligibility.

Если `expatlio_trial_1_Month` уже перешёл из `TRIAL` в `NORMAL`, пользователь
считается платным месячным подписчиком. В paywall его presentation kind —
«Месяц», но purchase target для смены плана остаётся
`expatlio_1_Month`; он выбирается по умолчанию, если доступен. Текущий
`expatlio_3_Month` выбирает трёхмесячную карточку.

## Каталог и данные

`SubscriptionService.loadSubscriptionCatalog()` по-прежнему одновременно
получает packages из offering `subscriptions` и прямые StoreKit products.
`PayWidget` строит карточки из ожидаемых product IDs и сопоставляет каждому
реальный `Package` или `StoreProduct`.

Для каждого плана UI использует:

- `priceString` для локализованной цены;
- фактический product ID для покупки;
- introductory offer metadata и
  `Purchases.checkTrialOrIntroductoryPriceEligibility()`;
- локальную бизнес-копию «3 дня бесплатно» только когда eligibility имеет
  значение `introEligibilityStatusEligible`, а metadata продукта содержит
  бесплатный трёхдневный offer.

Eligibility хранится как `eligible`, `ineligible`, `unknown` или `error`.
Только `eligible` разрешает trial-copy. `ineligible`, `unknown` и `error`
fail closed: экран не обещает бесплатный период и использует обычный месячный
продукт. Это соответствует рекомендации SDK показывать non-intro pricing при
unknown status.

Presentation-слот «Месяц» выбирает точный product ID так:

1. `eligible` + доступен `expatlio_trial_1_Month` — trial product;
2. иначе доступен `expatlio_1_Month` — обычный paid month;
3. иначе доступен `expatlio_trial_1_Month` — тот же месячный продукт, но без
   trial-copy: системный sheet Apple остаётся источником итоговой цены;
4. иначе месячный слот отсутствует.

Для одного product ID `Package` имеет приоритет перед прямым `StoreProduct`,
чтобы RevenueCat сохранил offering attribution. Прямой продукт используется
только как fallback. После загрузки UI оставляет лишь реально доступные слоты.
Если default отсутствует, выбирается первый доступный вариант; приоритет —
месяц, затем три месяца для нового пользователя и три месяца, затем месяц для
paid-upgrade flow.

Если Apple не вернула ни одного продукта, карточки не притворяются доступными.
Вместо повторяющегося `Недоступно` внутри карточек показывается один компактный
error-state с понятной причиной и кнопкой повторной загрузки. Доступные
продукты остаются покупаемыми при частичном каталоге.

## Компоновка

Экран остаётся нативным и спокойным:

1. короткий заголовок и одна строка ценности;
2. три коротких преимущества без больших декоративных блоков;
3. две компактные selectable-карточки одинаковой геометрии;
4. у трёхмесячного варианта бейдж «Выгоднее», без выдуманного процента скидки;
5. закреплённая CTA меняется вместе с выбором;
6. под CTA — краткие условия списания, автопродления и отмены;
7. «Восстановить покупки» остаётся вторичным текстовым действием.

Карточка месяца и CTA зависят от eligibility:

- `eligible`: «3 дня бесплатно, затем {цена}/месяц» и
  «Попробовать 3 дня бесплатно»;
- `ineligible/unknown/error` или paid-flow: «{цена} в месяц» и
  «Оформить месяц · {цена}»;
- карточка трёх месяцев: «{цена} за 3 месяца» и
  «Оформить 3 месяца · {цена}»;
- во время trial — «Начать Premium сейчас · {цена}».

Текст не обещает trial на обычном месячном продукте. Для пользователя, который
уже использовал introductory offer, системный purchase sheet Apple остаётся
окончательным источником применяемой цены.

## Состояния интерфейса

- `loading`: skeleton/loader занимает стабильное место, CTA заблокирована;
- `ready`: обе или доступная часть карточек активна;
- `partial`: отсутствующий план скрыт, доступный остаётся покупаемым;
- `noProducts/configuration/network/timeout`: единый error-state и CTA
  «Повторить загрузку»;
- `purchasing/restoring`: повторные commerce-действия заблокированы;
- cancel purchase: без красной ошибки;
- purchase failure: локализованный snackbar, выбор тарифа сохраняется.

После успешной покупки обновлённый `CustomerInfo` проверяется на активный
`Expatlio Pro`, затем экран ждёт существующий Firebase webhook mirror. При
готовом mirror paywall закрывается; при задержке остаётся открытым и объясняет,
что покупка обрабатывается. Cancel не показывает ошибку. Любая ошибка или
завершение restore/purchase снимает busy-state в `finally`.

Restore с активным entitlement использует тот же mirror/close flow. Restore
без покупок сообщает об отсутствии активных покупок и остаётся на paywall;
ошибка restore показывает snackbar и оставляет повтор доступным.

## Компоненты

- `PayWidget` владеет состоянием каталога, выбором и purchase orchestration.
- небольшой immutable `StudentPayPlanViewData` содержит presentation kind,
  точный product ID, `Package?`, `StoreProduct?`, eligibility, цену, copy и
  enabled-state; он не выполняет I/O;
- `StudentPayPlanCard` только отображает один доступный план и selection.
- новый небольшой `StudentPayCatalogError` отображает общий failure/retry.
- `StudentPayBottomBar` отображает CTA и юридическую строку, не решает, какой
  продукт покупать.

Компоненты не обращаются к `Purchases` напрямую и остаются тестируемыми через
существующий injected payment gateway.

## Проверка

1. Widget-тест: пользователь без подписки видит trial month и 3 months.
2. Widget-тест: выбор 3 months вызывает purchase с
   `expatlio_3_Month`.
3. Widget-тест: trial state показывает обычный month и 3 months.
4. Widget-тест: partial catalog скрывает отсутствующий план и оставляет
   доступный активным.
5. Widget-тест: пустой каталог показывает один error-state без повторяющихся
   `Недоступно`.
6. Geometry-тест: loading/error/ready не создают overflow на узком iPhone и
   при увеличенном text scale.
7. Unit/widget-тесты: eligibility `eligible/ineligible/unknown/error` выбирает
   корректный monthly product и никогда не обещает trial при fail-closed.
8. Widget-тесты: `premiumOnly` имеет высший приоритет; active trial и active
   paid показывают только корректные paid products.
9. Widget-тесты: partial catalog меняет selection на доступный вариант;
   `Package` имеет purchase-приоритет над direct `StoreProduct`.
10. Widget-тесты: точный product ID проверяется для trial month, ordinary
    month и 3 months.
11. Widget-тесты: purchase success/mirror success закрывает paywall; cancel,
    failure и delayed mirror оставляют его в корректном состоянии; restore
    проверяется для active/empty/failure outcomes и всегда снимает busy-state.
12. `flutter analyze` и релевантные `flutter test`.

## Вне текущей задачи

- изменение цен или App Store product metadata;
- RevenueCat Paywalls/Experiments;
- вычисление маркетингового процента скидки;
- отдельный Android paywall до создания Google Play products;
- полный редизайн остальных экранов приложения.
