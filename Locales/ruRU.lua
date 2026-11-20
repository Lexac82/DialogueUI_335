-- Русский. Strings come from the retail Dialogue UI locale where it has the same text, the rest are written for this port.
if not (GetLocale() == "ruRU") then return end;

local _, addon = ...;
local L = addon.L;

-- Blizzard's own global strings are used where they exist (they follow the client language). The text below is the fallback.

-- Footer buttons
L["Accept"] = ACCEPT or "Принять";
L["Continue"] = CONTINUE or "Продолжить";
L["Complete Quest"] = COMPLETE or "Завершить";
L["Incomplete"] = INCOMPLETE or "Не завершено";
L["Decline"] = DECLINE or "Отказаться";
L["Cancel"] = CANCEL or "Отмена";
L["Goodbye"] = GOODBYE or "До встречи";

-- Settings window
L["UI"] = "Интерфейс";
L["Control"] = "Управление";
L["Gameplay"] = "Игровой процесс";
L["Minimap"] = "Миникарта";

-- Settings: Compatibility
L["Compatibility"] = "Совместимость";
L["Disable DUI In Instance"] = "Использовать стандартный интерфейс в подземельях";
L["Disable DUI In Instance Desc"] = "Отключить Dialogue UI и использовать стандартный интерфейс игры, когда вы находитесь в подземелье или рейде.";

-- Settings: Minimap tab and minimap button
L["Show Minimap Button"] = "Показывать кнопку у миникарты";
L["Show Minimap Button Desc"] = "Показывает у миникарты кнопку, открывающую эти настройки. Перетащите её, чтобы переместить вокруг миникарты.";
L["Minimap Button Tooltip"] = "Нажмите, чтобы открыть настройки.";
L["Minimap Button Drag"] = "Перетащите, чтобы переместить";

-- Settings: UI tab
L["Theme"] = "Тема";
L["Theme Desc"] = "Выберите цветовую тему интерфейса.";
L["Theme Brown"] = "Коричневая";
L["Theme Dark"] = "Тёмная";
L["Frame Size"] = "Размер окна";
L["Frame Size Desc"] = "Выберите размер окна.\n\nПо умолчанию: Средний";
L["Size Extra Small"] = "Очень малый";
L["Size Small"] = "Малый";
L["Size Medium"] = "Средний";
L["Size Large"] = "Большой";
L["Open Animation"] = "Анимация открытия";
L["Open Animation Desc"] = "Сколько времени открывается окно диалога. 0с показывает его сразу.\n\nПо умолчанию: 0,25с";
L["Font Size"] = "Размер шрифта";
L["Font Size Desc"] = "Выберите размер шрифта.\n\nПо умолчанию: 12";
L["Frame Orientation"] = "Расположение";
L["Frame Orientation Desc"] = "Размещает интерфейс слева или справа на экране.\n\nПункт «Своё» позволяет перетаскивать интерфейс куда угодно, пока это окно открыто.\n\nПо умолчанию: справа";
L["Orientation Left"] = "Слева";
L["Orientation Right"] = "Справа";
L["Orientation Custom"] = "Своё";
L["Move Position"] = "Перетащить";
L["Reset Position"] = "Вернуть позицию по умолчанию";
L["Move Position Desc"] = "Показывает интерфейс, чтобы вы могли перетащить его на новое место.";
L["Reset Position Desc"] = "Сбрасывает положение интерфейса.";
L["Hide UI"] = "Скрыть интерфейс";
L["Hide UI Desc"] = "Скрыть интерфейс игры, когда вы взаимодействуете с NPC.";
L["Show NPC Name On Page"] = "Имя NPC";
L["Show NPC Name On Page Desc"] = "Отображать имя NPC в окне.";
L["Show Quest Type"] = "Показывать тип задания";
L["Show Quest Type Desc"] = "Показывает тип задания (обычное, ежедневное, еженедельное, подземелье, ...) над названием задания.";
L["Show Copy Text Button"] = "Кнопка копирования текста";
L["Show Copy Text Button Desc"] = "Показывает кнопку «Копировать текст» в правом верхнем углу интерфейса диалога.\n\nТакже включает игровые данные, например ID NPC и предметов (и ID заданий, которые уже есть в вашем журнале).";
L["Copy Text"] = "Скопировать текст";
L["Drag To Move"] = "Зажмите ЛКМ и тащите курсор, чтобы переместить окно.";
L["Edit Mode Title"] = "Dialogue UI";
L["Edit Mode Body"] = "Перетащите это окно, куда хотите. Закройте окно настроек, чтобы скрыть его.";

-- Quest types and tags
L["Quest"] = "Задание";
L["Readables"] = "Читаемые";
L["BookUI Frame Size Desc"] = "Задаёт размер интерфейса книг.\n\nПо умолчанию: маленький";
L["BookUI Keep UI Open"] = "Держать открытым";
L["BookUI Keep UI Open Desc"] = "Держать окно открытым, когда вы отходите от объекта.\n\nНажмите Escape или щелкните правой кнопкой мыши по окну, чтобы закрыть его.";
L["BookUI Show Location"] = "Показать местоположение";
L["BookUI Show Location Desc"] = "Показывать местоположение объекта в заголовке.\n\nРаботает только с игровыми объектами, а не с предметами в ваших сумках.";
L["BookUI Show Item Description"] = "Показать описание предмета";
L["BookUI Show Item Description Desc"] = "Если у предмета есть какое-либо описание во всплывающей подсказке, отобразить его в верхней части.";
L["BookUI Darken Screen"] = "Затемнить экран";
L["BookUI Darken Screen Desc"] = "Затемнить область вокруг, чтобы помочь вам сосредоточиться на содержимом.";

-- Settings: Control tab (retail enUS where it exists)
L["Input Device"] = "Устройство ввода";
L["Input Device Desc"] = "Влияет на значки горячих клавиш и макет интерфейса.";
L["Input Device KBM"] = "Клавиатура и мышь";
L["Use Custom Bindings"] = "Использовать собственные назначения";
L["Use Custom Bindings Desc"] = "Включите для использования ваших собственных назначений.";
L["Primary Control Key Desc"] = "Нажмите эту клавишу, чтобы выбрать первый доступный вариант, например, принять задание.";
L["Right Click To Close UI"] = "ПКМ для закрытия";
L["Right Click To Close UI Desc"] = "Щелкните правой кнопкой мыши по диалоговому окну, чтобы закрыть его.";
L["Press Button To Scroll Down"] = "Нажатие клавиши для прокрутки вниз";
L["Press Button To Scroll Down Desc"] = "Если содержимое превышает высоту окна, нажатие клавиши подтверждения приведет к прокрутке страницы вниз вместо принятия задания.";
L["Press Escape To Decline Quest"] = "Нажатие Escape для отказа от задания";
L["Press Escape To Decline Quest Desc"] = "При просмотре задания от NPC с несколькими вариантами диалога, нажатие клавиши Escape не закрывает интерфейс, а возвращает на предыдущую страницу.";
L["Press Tab To Select Reward"] = "Клавиша Tab для выбора награды";
L["Press Tab To Select Reward Desc"] = "Нажимайте Tab, чтобы перебирать доступные для выбора награды при сдаче задания. Shift+Tab — назад.";
L["Keybinding Hint"] = "Нажмите, затем нажмите нужную клавишу.\nПравый щелчок: вернуть клавишу по умолчанию.\nEsc: отмена.";
L["Bound To"] = "Назначено на: ";
L["Not Bound"] = NOT_BOUND or "Не назначено";
L["Action Confirm"] = "Подтверждение";
L["Action Settings"] = "Переключение видимости настроек";
L["Action Option1"] = "Вариант 1";
L["Action Option2"] = "Вариант 2";
L["Action Option3"] = "Вариант 3";
L["Action Option4"] = "Вариант 4";
L["Action Option5"] = "Вариант 5";
L["Action Option6"] = "Вариант 6";
L["Action Option7"] = "Вариант 7";
L["Action Option8"] = "Вариант 8";
L["Action Option9"] = "Вариант 9";
L["Action Option Desc"] = "Нажмите эту клавишу, чтобы выбрать пункт %d списка (задания и варианты диалога).";
L["Action Settings Desc"] = "Нажмите эту клавишу, чтобы открыть или закрыть окно настроек, пока показан диалог.";

L["Quest Frequency Daily"] = "Ежедневное";
L["Quest Frequency Weekly"] = "Еженедельное";
L["Quest Type Repeatable"] = "Повторяемое";
L["Quest Difficulty VeryHard"] = "Очень сложное";
L["Quest Difficulty Hard"] = "Сложное";
L["Quest Difficulty Easy"] = "Лёгкое";
L["Quest Difficulty Trivial"] = "Низкий уровень";
L["Quest Difficulty Option"] = "Сложность заданий";
L["Instant Quest Text"] = "Мгновенный текст задания";
L["Instant Quest Text Desc"] = "Показывает текст задания сразу, а не плавно проявляет его. Используется та же настройка игры, что и у параметра текста заданий от Blizzard.";
L["Mark Highest Sell Price"] = "Метка самой высокой цены продажи";
L["Mark Highest Sell Price Desc"] = "Покажет вам, какой товар имеет самую высокую цену продажи при выборе награды.";
L["Use Blizzard Tooltip"] = "Стандартная подсказка";
L["Use Blizzard Tooltip Desc"] = "Использовать стандартную подсказку игры для награды за выполнение задания вместо нашей специальной подсказки.";
L["Show Transmog Status"] = "Показывать несобранные образы";
L["Show Transmog Status Desc"] = "Отмечает предметы-награды, образ которых для трансмогрификации вы ещё не собрали, и добавляет строку в их подсказку.\n\n|cffff8040На сервере должен быть установлен модуль системы трансмогрификации (mod-transmog).|r Без него ничего не отображается.\n\nАддон один раз выполняет команду .transmog sync и скрывает её вывод в окне чата.";
L["Use Transmog Plus"] = "Используется Mod Transmog Plus";
L["Use Transmog Plus Desc"] = "Включите, если на сервере работает mod-transmog-plus вместо оригинального mod-transmog. Тогда сервер отвечает по каждому предмету и считает образ собранным, если собран любой предмет с той же моделью.\n\nДля оригинального mod-transmog оставьте выключенным.";
L["Transmog Not Collected"] = "Образ не собран";
L["Click To Copy To Clipboard"] = "Нажмите, чтобы скопировать в буфер обмена";
L["Show Upgrade Arrow"] = "Показывать стрелку улучшения (нужен Pawn)";
L["Show Upgrade Arrow Desc"] = "Показывает зелёную стрелку %s на предмете-награде, если он улучшает вашего персонажа по данным аддона Pawn: предмет получает больше очков, чем надетый в этом слоте, хотя бы по одной из ваших шкал Pawn.\n\nДоспехи другого типа, чем надетые (например, ткань вместо кожи), никогда не отмечаются.";
L["Show Upgrade Arrow Pawn Missing"] = "Требуется аддон Pawn (не найден).\n\nСкачать: |cff0000ee%s|r\n\nНажмите на значок копирования, нажмите Ctrl+C и вставьте ссылку в браузер.";
L["Quest Difficulty Option Desc"] = "Выберите, как показывать сложность заданий, когда NPC предлагает список заданий.";
L["QuestDifficultyStyle Off"] = "ВЫКЛ";
L["QuestDifficultyStyle Off Desc"] = "Уровень и сложность заданий теперь скрыты.";
L["QuestDifficultyStyle Level"] = "Уровень";
L["QuestDifficultyStyle Level Desc"] = "Показывает уровень задания слева от его названия.";
L["QuestDifficultyStyle Name"] = "Название";
L["QuestDifficultyStyle Both"] = "Оба";
L["QuestDifficultyStyle Both Desc"] = "Показывает уровень задания слева от названия, а название сложности справа от кнопки задания, если уровень задания вне рекомендуемого диапазона.";
L["QuestDifficultyStyle Name Desc"] = "Показывает название сложности справа от кнопки задания, если уровень задания вне рекомендуемого диапазона.\n(Уровень задания на 3 выше или ниже уровня вашего персонажа.)";
L["Quest Type Trivial"] = "Простое";
L["Quest Type Dungeon"] = "Подземелье";
L["Quest Type Raid"] = "Рейд";
L["Quest Type Heroic"] = "Героическое";
L["Quest Type Elite"] = "Элитное";
L["Quest Type Group"] = "Групповое";
L["Quest Type PvP"] = "PvP";

-- Quest text
L["Quest Objectives"] = "Задачи";
L["Format Suggested Players"] = QUEST_SUGGESTED_GROUP_NUM or "Рекомендуется %d |4игрок:игрока:игроков;.";
L["Quest Accepted Alert"] = ERR_QUEST_ACCEPTED_S or "Задание принято: %s";

-- Rewards
L["Reward"] = "Награда";
L["Rewards"] = "Награды";
L["Reward Choose"] = REWARD_CHOOSE or "Выберите награду:";
L["Reward Choices"] = REWARD_CHOICES or "Вы сможете выбрать одну из этих наград:";
L["Reward Items"] = REWARD_ITEMS or "Вы также получите:";
L["Requirements"] = "Требования";
L["Money"] = MONEY or "Деньги";
L["Honor Points"] = "Честь";
L["Arena Points"] = "Очки арены";
L["Talent Points"] = "Очки талантов";
L["Experience"] = "Опыт";
L["Title"] = "Звание";
L["Format Talent Point Row"] = "+%d очко талантов";
L["Format Talent Points Row"] = "+%d очков талантов";

-- Reward tooltip
L["Show Comparison"] = "Показать сравнение";
L["Hide Comparison"] = "Скрыть сравнение";
L["Sell Price"] = SELL_PRICE or "Цена продажи";
L["Format Item Level"] = ITEM_LEVEL or "Уровень предмета %d";
L["Format You Have"] = "- У вас есть |cffffffff%d|r";
L["Format In Bank"] = " (|cffffffff%d|r в банке)";
L["Format Replace Item"] = "Заменить %s";
L["Equipped Item"] = "надетый предмет";
L["Different Item Type"] = "Тип предмета отличается от надетого.";
L["Identical Stats"] = "Одинаковые характеристики";
L["Format Reward Title"] = "Вам будет присвоено звание «%s».";
L["Format Reward Honor"] = "Вы получите очков чести: %d.";
L["Format Reward Talent Point"] = "Вы получите очков талантов: %d.";
L["Format Reward Talent Points"] = "Вы получите очков талантов: %d.";
L["Format Reward Arena"] = "Вы получите очков арены: %d.";
L["Format Reward Experience"] = "Вы получите опыта: %d%s.";
L["Format Of Your Level"] = " (%d%% вашего уровня)";

-- Quest Item Display
L["Quest Item Display"] = "Отображение предмета для задания";
L["Quest Item Display Desc"] = "Автоматическое отображение описания предмета для задания и возможность использовать его, не открывая сумки.";
L["Quest Item Display Hide Seen"] = "Игнорировать просмотренные предметы";
L["Quest Item Display Hide Seen Desc"] = "Игнорировать предметы, которые были обнаружены кем-либо из ваших персонажей.";
L["Quest Item Display Await World Map"] = " Ожидание Карты мира";
L["Quest Item Display Await World Map Desc"] = "При открытии Карты мира временно скрывать \"Описания предмета для задания\" и ставить на паузу таймер его авто-скрытия.";
L["Quest Item Display Reset Position Desc"] = "Сбросить положение окна.";
L["Valuable Reward Popup"] = "Окно ценной награды (нужен Pawn)";
L["Valuable Reward Popup Sample"] = "Окно ценной награды";
L["Valuable Reward Popup Desc"] = "Когда за задание вы получаете предмет, улучшающий вашего персонажа по данным аддона Pawn, показывается кнопка, позволяющая сразу надеть его.\n\nВ бою кнопка отключена.";
L["Item Equipped"] = "Экипирован";
L["Press Key To Use Item"] = "Нажать клавишу для использования";
L["Press Key To Use Item Desc Generic"] = "Нажмите кнопку подтверждения (сейчас: %s), чтобы использовать предмет вне боя.";
L["Press Key To Use Item Desc PC"] = "Нажмите пробел, чтобы использовать предмет вне боя.";
L["Click To Read"] = "Щелкните левой кнопкой мыши, чтобы прочитать";
L["Begins A Quest"] = "Начинает задание";

-- Supported addons
L["Format Reward Title Row"] = "Звание: %s";
L["On Your Gear List"] = "В вашем списке экипировки";
L["Format Exchange It For"] = "Обменять на: %s";
