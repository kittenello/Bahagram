import Display
import AccountContext
import BGSimpleSettings

public func bgSpySettingsController(context: AccountContext) -> ViewController {
    let s = BGSimpleSettings.shared
    return bgController(context: context, title: "Bahogram", entries: {
        var result: [BGListEntry] = [.header(0, 0, "РЕЖИМ ПРИЗРАКА"), .disclosure(1, 0, "ghost", "Режим призрака", s.ghostModeEnabled ? "Включен" : "Выключен"), .header(10, 1, "СОХРАНЕНИЕ СООБЩЕНИЙ"), .toggle(11, 1, "saveDeleted", "Сохранять удаленки", s.saveDeletedMessages, true)]
        if s.saveDeletedMessages { result.append(.toggle(12, 1, "transparentDeleted", "Полупрозрачные удаленки", s.semiTransparentDeletedMessages, true)) }
        result.append(contentsOf: [.toggle(13, 1, "saveEdits", "Сохранять историю правок", s.saveEditHistory, true), .toggle(14, 1, "saveOnce", "Сохранять одноразки", s.saveViewOnceMedia, true), .toggle(15, 1, "saveBots", "Сохранять в чатах с ботами", s.saveInBotChats, true), .header(20, 2, "ПЕРЕСЫЛКА"), .toggle(21, 2, "bypassForward", "Запрещенная рассылка", s.bypassForwardRestrictions, true), .info(22, 2, "Скачивает защищённый текст и медиа, затем отправляет их как новое сообщение без подписи «Переслано»."), .header(30, 3, "ДРУГОЕ"), .disclosure(31, 3, "visualPhone", "Визуальный номер", s.visualPhoneEnabled ? (s.visualPhoneNumber.isEmpty ? "Включен" : s.visualPhoneNumber) : "Выключен")])
        return result
    }, toggle: { key, value in
        switch key { case "saveDeleted": s.saveDeletedMessages = value; case "transparentDeleted": s.semiTransparentDeletedMessages = value; case "saveEdits": s.saveEditHistory = value; case "saveOnce": s.saveViewOnceMedia = value; case "saveBots": s.saveInBotChats = value; case "bypassForward": s.bypassForwardRestrictions = value; default: break }
    }, open: { key in key == "ghost" ? bgGhostSettingsController(context: context) : (key == "visualPhone" ? bgVisualPhoneController(context: context) : nil) })
}

private func bgVisualPhoneController(context: AccountContext) -> ViewController {
    let s = BGSimpleSettings.shared
    return bgController(context: context, title: "Визуальный номер", entries: {
        [.header(0, 0, "ПОДМЕНА НОМЕРА"), .toggle(1, 0, "enabled", "Показывать другой номер", s.visualPhoneEnabled, true), .input(2, 0, "number", s.visualPhoneNumber, "+888 0156 2794"), .info(3, 0, "Меняется только отображение номера в вашем профиле на этом устройстве. Реальный номер Telegram и данные аккаунта остаются прежними.")]
    }, toggle: { key, value in
        if key == "enabled" { s.visualPhoneEnabled = value }
    }, textUpdated: { key, value in
        if key == "number" { s.visualPhoneNumber = value }
    })
}

private func bgGhostSettingsController(context: AccountContext) -> ViewController {
    let s = BGSimpleSettings.shared
    return bgController(context: context, title: "Режим призрака", entries: {
        let count = [s.ghostReadMessages, s.ghostReadStories, s.ghostSendOnline, s.ghostSendTyping, !s.ghostAutomaticOffline].filter { !$0 }.count
        let silent = ["Никогда", "В режиме призрака", "Всегда"][min(max(s.ghostSendWithoutSound, 0), 2)]
        return [.header(0, 0, "РЕЖИМ ПРИЗРАКА"), .toggle(1, 0, "enabled", "Режим призрака", s.ghostModeEnabled, true), .disclosure(2, 0, "options", "Параметры режима призрака", "\(count)/5"), .toggle(3, 0, "readOnAction", "Читать при действиях", s.ghostReadOnAction, s.ghostModeEnabled), .toggle(4, 0, "scheduled", "Использовать отложку", s.ghostUseScheduledMessages, s.ghostModeEnabled), .disclosure(5, 0, "silent", "Отправлять без звука", silent), .toggle(6, 0, "stories", "Предлагать призрака для сторис", s.ghostSuggestForStories, true), .info(7, 0, "Управляет отметками о прочтении, просмотре сторис, статусом онлайн и набором текста.")]
    }, toggle: { key, value in
        switch key { case "enabled": s.ghostModeEnabled = value; case "readOnAction": s.ghostReadOnAction = value; case "scheduled": s.ghostUseScheduledMessages = value; case "stories": s.ghostSuggestForStories = value; default: break }
    }, open: { key in key == "options" ? bgGhostOptionsController(context: context) : (key == "silent" ? bgSilentModeController(context: context) : nil) })
}

private func bgGhostOptionsController(context: AccountContext) -> ViewController {
    let s = BGSimpleSettings.shared
    return bgController(context: context, title: "Параметры призрака", entries: {
        [.header(0, 0, "НЕ ОТПРАВЛЯТЬ"), .toggle(1, 0, "messages", "Отметки о прочтении сообщений", !s.ghostReadMessages, true), .toggle(2, 0, "stories", "Отметки о просмотре историй", !s.ghostReadStories, true), .toggle(3, 0, "online", "Статус «онлайн»", !s.ghostSendOnline, true), .toggle(4, 0, "typing", "Статус «печатает»", !s.ghostSendTyping, true), .toggle(5, 0, "offline", "Автоматический «офлайн»", s.ghostAutomaticOffline, true)]
    }, toggle: { key, value in
        switch key { case "messages": s.ghostReadMessages = !value; case "stories": s.ghostReadStories = !value; case "online": s.ghostSendOnline = !value; case "typing": s.ghostSendTyping = !value; case "offline": s.ghostAutomaticOffline = value; default: break }
    })
}

private func bgSilentModeController(context: AccountContext) -> ViewController {
    let s = BGSimpleSettings.shared
    return bgController(context: context, title: "Отправлять без звука", entries: { [.checkbox(0, 0, "0", "Никогда", s.ghostSendWithoutSound == 0), .checkbox(1, 0, "1", "В режиме призрака", s.ghostSendWithoutSound == 1), .checkbox(2, 0, "2", "Всегда", s.ghostSendWithoutSound == 2)] }, select: { s.ghostSendWithoutSound = Int($0) ?? 0 })
}

func bgAppearanceSettingsController(context: AccountContext) -> ViewController {
    let s = BGSimpleSettings.shared
    return bgController(context: context, title: "Оформление", entries: {
        [.header(0, 0, "ОСНОВНОЕ"), .toggle(1, 0, "premiumStatuses", "Скрыть премиум статусы", s.hidePremiumStatuses, true), .toggle(2, 0, "customBackgrounds", "Отключить кастомные фоны", s.disableCustomBackgrounds, true), .toggle(3, 0, "hideStories", "Скрыть сторис", s.hideStories, true), .header(10, 1, "ПРИЛОЖЕНИЕ"), .appIcons(11, 1), .header(20, 2, "ВКЛАДКИ"), .toggle(21, 2, "hideTabBar", "Скрыть панель вкладок", s.hideTabBar, true), .toggle(22, 2, "contacts", "Вкладка Контакты", s.showContactsTab, !s.hideTabBar), .toggle(23, 2, "calls", "Вкладка Звонки", s.showCallsTab, !s.hideTabBar), .toggle(24, 2, "wideTabBar", "Широкая Панель", s.wideTabBar, !s.hideTabBar), .header(30, 3, "ПРОФИЛИ"), .toggle(31, 3, "profileId", "ID Профилей", s.showProfileId, true), .toggle(32, 3, "dc", "Показывать дата-центр (DC)", s.showDc, true), .toggle(33, 3, "regDate", "Показывать дату регистрации", s.showRegistrationDate, true), .toggle(34, 3, "chatDate", "Показывать дату создания чата", s.showChatCreationDate, true), .toggle(35, 3, "confirmCalls", "Подтверждение вызова", s.confirmCalls, true), .header(40, 4, "ДРУГОЕ"), .toggle(41, 4, "disableAds", "Отключить рекламу", s.disableAds, true)]
    }, restartRequiredKeys: ["premiumStatuses", "hideStories", "hideTabBar", "contacts", "calls", "wideTabBar"], toggle: { key, value in
        switch key { case "premiumStatuses": s.hidePremiumStatuses = value; case "customBackgrounds": s.disableCustomBackgrounds = value; case "hideStories": s.hideStories = value; case "hideTabBar": s.hideTabBar = value; case "contacts": s.showContactsTab = value; case "calls": s.showCallsTab = value; case "wideTabBar": s.wideTabBar = value; case "profileId": s.showProfileId = value; case "dc": s.showDc = value; case "regDate": s.showRegistrationDate = value; case "chatDate": s.showChatCreationDate = value; case "confirmCalls": s.confirmCalls = value; case "disableAds": s.disableAds = value; default: break }
    })
}

func bgChatsSettingsController(context: AccountContext) -> ViewController {
    let s = BGSimpleSettings.shared
    return bgController(context: context, title: "Чаты", entries: {
        let hiddenCount = [1, 2, 4].filter { s.hiddenReactions & $0 != 0 }.count
        let transcription = s.transcriptionBackend == .apple ? "Apple" : "Telegram"
        return [.header(0, 0, "СТИКЕРЫ И ЭМОДЗИ"), .toggle(1, 0, "onlyAdded", "Показывать только добавленные стикеры", s.onlyAddedStickers, true), .toggle(2, 0, "recent", "Беск. недавние стикеры", s.infiniteRecentStickers, true), .disclosure(3, 0, "reactions", "Скрыть реакции", "\(hiddenCount)/3"), .header(10, 1, "СООБЩЕНИЯ"), .messagePreview(11, 1, s.removeMessageTails), .toggle(12, 1, "tails", "Убрать хвост у сообщений", s.removeMessageTails, true), .toggle(13, 1, "seconds", "Показывать секунды", s.showMessageSeconds, true), .toggle(14, 1, "replies", "Отключить цветные ответы", s.disableColoredReplies, true), .header(20, 2, "ГОЛОС В ТЕКСТ"), .disclosure(21, 2, "transcription", "Сервис", transcription)]
    }, toggle: { key, value in
        switch key { case "onlyAdded": s.onlyAddedStickers = value; case "recent": s.infiniteRecentStickers = value; case "tails": s.removeMessageTails = value; case "seconds": s.showMessageSeconds = value; case "replies": s.disableColoredReplies = value; default: break }
    }, open: { key in key == "reactions" ? bgHiddenReactionsController(context: context) : (key == "transcription" ? bgTranscriptionController(context: context) : nil) })
}

private func bgTranscriptionController(context: AccountContext) -> ViewController {
    let s = BGSimpleSettings.shared
    return bgController(context: context, title: "Голос в текст", entries: {
        [.checkbox(0, 0, "telegram", "Telegram", s.transcriptionBackend == .telegram), .checkbox(1, 0, "apple", "Apple", s.transcriptionBackend == .apple), .info(2, 0, s.transcriptionBackend == .apple ? "Apple распознаёт голосовые сообщения локально на устройстве." : "Telegram использует облачный сервис распознавания.")]
    }, select: { s.transcriptionBackend = BGSimpleSettings.TranscriptionBackend(rawValue: $0) ?? .telegram })
}

private func bgHiddenReactionsController(context: AccountContext) -> ViewController {
    let s = BGSimpleSettings.shared
    return bgController(context: context, title: "Скрыть реакции", entries: { [.toggle(0, 0, "1", "Каналы", s.hiddenReactions & 1 != 0, true), .toggle(1, 0, "2", "Группы", s.hiddenReactions & 2 != 0, true), .toggle(2, 0, "4", "Личные чаты", s.hiddenReactions & 4 != 0, true)] }, toggle: { key, value in
        let mask = Int(key) ?? 0
        s.hiddenReactions = value ? (s.hiddenReactions | mask) : (s.hiddenReactions & ~mask)
    })
}

func bgSupportController(context: AccountContext) -> ViewController {
    bgController(context: context, title: "Поддержка", entries: { [.header(0, 0, "ПОДДЕРЖКА"), .info(1, 0, "Раздел подготовлен для ссылок на поддержку и информацию о Bahogram.")] })
}
