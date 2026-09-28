import Display
import AccountContext
import DGSimpleSettings
import Postbox
import SwiftSignalKit
import TelegramUIPreferences
import TelegramCore

public func dgSpySettingsController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    let accountId = context.account.peerId.toInt64()
    return dgController(context: context, title: "Основные", entries: {
        var result: [DGListEntry] = [.header(0, 0, "РЕЖИМ ПРИЗРАКА"), .disclosure(1, 0, "ghost", "Режим призрака", s.ghostModeEnabled ? "Включен" : "Выключен"), .header(10, 1, "СОХРАНЕНИЕ СООБЩЕНИЙ"), .toggle(11, 1, "saveDeleted", "Сохранять удаленки", s.saveDeletedMessages, true)]
        if s.saveDeletedMessages { result.append(.toggle(12, 1, "transparentDeleted", "Полупрозрачные удаленки", s.semiTransparentDeletedMessages, true)) }
        result.append(contentsOf: [.toggle(13, 1, "saveEdits", "Сохранять историю правок", s.saveEditHistory, true), .toggle(14, 1, "saveOnce", "Сохранять одноразки", s.saveViewOnceMedia, true), .toggle(15, 1, "saveBots", "Сохранять в чатах с ботами", s.saveInBotChats, true), .toggle(16, 1, "disappearedGifts", "Видеть удаленные подарки", s.showDisappearedGifts, true), .header(20, 2, "ПЕРЕСЫЛКА"), .toggle(21, 2, "bypassForward", "Запрещенная рассылка", s.bypassForwardRestrictions, true), .header(25, 3, "УСКОРЕНИЕ ЗАГРУЗКИ"), .speedSlider(26, 3, s.downloadAcceleration), .toggle(27, 3, "accelerateUpload", "Ускорение отправки", s.accelerateUpload, true), .info(28, 3, "Ультра использует больше одновременных соединений. На медленном интернете это может мешать загрузке файлов и просмотру видео."), .header(30, 4, "ДРУГОЕ"), .disclosure(31, 4, "visualPhone", "Визуальный номер", s.visualPhoneEnabled ? (s.visualPhoneNumber.isEmpty ? "Включен" : s.visualPhoneNumber) : "Выключен"), .disclosure(32, 4, "visualRating", "Визуальный рейтинг", s.visualRatingLevel(accountId: accountId).map { String($0) } ?? "Выключен"), .disclosure(33, 4, "visualUsernames", "Визуальные NFT-юзернеймы", "\(s.visualUsernames(accountId: accountId).count)"), .disclosure(34, 4, "visualId", "Визуальный ID", s.visualProfileId(accountId: accountId).isEmpty ? "Выключен" : s.visualProfileId(accountId: accountId)), .toggle(35, 4, "localPremium", "Локальный TG Premium", s.localPremium(accountId: accountId), true)])
        if s.localPremium(accountId: accountId) {
            result.append(.info(36, 4, "Premium включён локально для этого аккаунта. Сервер Telegram по-прежнему проверяет подписку для платных возможностей."))
        }
        return result
    }, restartRequiredKeys: ["localPremium"], toggle: { key, value in
        switch key { case "saveDeleted": s.saveDeletedMessages = value; case "transparentDeleted": s.semiTransparentDeletedMessages = value; case "saveEdits": s.saveEditHistory = value; case "saveOnce": s.saveViewOnceMedia = value; case "saveBots": s.saveInBotChats = value; case "disappearedGifts": s.showDisappearedGifts = value; case "bypassForward": s.bypassForwardRestrictions = value; case "accelerateUpload": s.accelerateUpload = value; case "localPremium": s.setLocalPremium(value, accountId: accountId); default: break }
    }, select: { key in
        if key.hasPrefix("downloadAcceleration:"), let value = Int(key.split(separator: ":").last ?? "") { s.downloadAcceleration = value }
    }, open: { key in
        switch key {
        case "ghost": return dgGhostSettingsController(context: context)
        case "visualPhone": return dgVisualPhoneController(context: context)
        case "visualRating": return dgVisualRatingController(context: context)
        case "visualUsernames": return dgVisualUsernamesController(context: context)
        case "visualId": return dgVisualIdController(context: context)
        default: return nil
        }
    })
}

private func dgVisualIdController(context: AccountContext) -> ViewController {
    let settings = DGSimpleSettings.shared
    let accountId = context.account.peerId.toInt64()
    return dgController(context: context, title: "Визуальный ID", entries: {
        [.header(0, 0, "ID ПРОФИЛЯ"), .input(1, 0, "visualId", settings.visualProfileId(accountId: accountId), "Любой текст"), .info(2, 0, "Меняется только ID в вашем профиле на этом устройстве. Пустое поле возвращает настоящий ID. Нажатие на ID копирует настоящий номер Telegram.")]
    }, textUpdated: { key, value in
        if key == "visualId" { settings.setVisualProfileId(value, accountId: accountId) }
    })
}

private func dgVisualRatingController(context: AccountContext) -> ViewController {
    let settings = DGSimpleSettings.shared
    let accountId = context.account.peerId.toInt64()
    return dgController(context: context, title: "Визуальный рейтинг", entries: {
        [.header(0, 0, "УРОВЕНЬ"), .input(1, 0, "level", settings.visualRatingLevel(accountId: accountId).map { String($0) } ?? "", "1–100"), .info(2, 0, "Укажите уровень от 1 до 100. Значок и его узор выбираются тем же компонентом, что и в Telegram. Пустое поле возвращает реальный рейтинг. Изменение видно только в Donutgram на этом устройстве.")]
    }, textUpdated: { key, value in
        if key == "level" { settings.setVisualRatingLevel(Int(value), accountId: accountId) }
    })
}

private func dgVisualUsernamesController(context: AccountContext) -> ViewController {
    let settings = DGSimpleSettings.shared
    let accountId = context.account.peerId.toInt64()
    return dgController(context: context, title: "Визуальные NFT-юзернеймы", entries: {
        [.header(0, 0, "ИМЕНА ЧЕРЕЗ ЗАПЯТУЮ"), .input(1, 0, "names", settings.visualUsernames(accountId: accountId).map { "@\($0.name)" }.joined(separator: ", "), "@username, @username2"), .info(2, 0, "Имена добавляются только локально. Активность и порядок меняются в редакторе имён. Карточка Telegram покажет дату добавления и условную цену от 9 TON. Реальные ссылки, владельцы и данные Telegram не меняются.")]
    }, textUpdated: { key, value in
        if key == "names" { settings.updateVisualUsernames(value, accountId: accountId) }
    })
}

private func dgVisualPhoneController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Визуальный номер", entries: {
        [.header(0, 0, "ПОДМЕНА НОМЕРА"), .toggle(1, 0, "enabled", "Показывать другой номер", s.visualPhoneEnabled, true), .input(2, 0, "number", s.visualPhoneNumber, "+888 0156 2794"), .info(3, 0, "Меняется только отображение номера в вашем профиле на этом устройстве. Реальный номер Telegram и данные аккаунта остаются прежними.")]
    }, toggle: { key, value in
        if key == "enabled" { s.visualPhoneEnabled = value }
    }, textUpdated: { key, value in
        if key == "number" { s.visualPhoneNumber = value }
    })
}

private func dgGhostSettingsController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Режим призрака", entries: {
        let count = [s.ghostReadMessages, s.ghostReadStories, s.ghostSendOnline, s.ghostSendTyping, !s.ghostAutomaticOffline].filter { !$0 }.count
        let silent = ["Никогда", "В режиме призрака", "Всегда"][min(max(s.ghostSendWithoutSound, 0), 2)]
        return [.header(0, 0, "РЕЖИМ ПРИЗРАКА"), .toggle(1, 0, "enabled", "Режим призрака", s.ghostModeEnabled, true), .disclosure(2, 0, "options", "Параметры режима призрака", "\(count)/5"), .toggle(3, 0, "readOnAction", "Читать при действиях", s.ghostReadOnAction, s.ghostModeEnabled), .toggle(4, 0, "scheduled", "Использовать отложку", s.ghostUseScheduledMessages, s.ghostModeEnabled), .disclosure(5, 0, "silent", "Отправлять без звука", silent), .toggle(6, 0, "stories", "Предлагать призрака для сторис", s.ghostSuggestForStories, true)]
    }, toggle: { key, value in
        switch key { case "enabled": s.ghostModeEnabled = value; case "readOnAction": s.ghostReadOnAction = value; case "scheduled": s.ghostUseScheduledMessages = value; case "stories": s.ghostSuggestForStories = value; default: break }
    }, open: { key in key == "options" ? dgGhostOptionsController(context: context) : (key == "silent" ? dgSilentModeController(context: context) : nil) })
}

private func dgGhostOptionsController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Параметры призрака", entries: {
        [.header(0, 0, "НЕ ОТПРАВЛЯТЬ"), .toggle(1, 0, "messages", "Отметки о прочтении сообщений", !s.ghostReadMessages, true), .toggle(2, 0, "stories", "Отметки о просмотре историй", !s.ghostReadStories, true), .toggle(3, 0, "online", "Статус «онлайн»", !s.ghostSendOnline, true), .toggle(4, 0, "typing", "Статус «печатает»", !s.ghostSendTyping, true), .toggle(5, 0, "offline", "Автоматический «офлайн»", s.ghostAutomaticOffline, true)]
    }, toggle: { key, value in
        switch key { case "messages": s.ghostReadMessages = !value; case "stories": s.ghostReadStories = !value; case "online": s.ghostSendOnline = !value; case "typing": s.ghostSendTyping = !value; case "offline": s.ghostAutomaticOffline = value; default: break }
    })
}

private func dgSilentModeController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Отправлять без звука", entries: { [.checkbox(0, 0, "0", "Никогда", s.ghostSendWithoutSound == 0), .checkbox(1, 0, "1", "В режиме призрака", s.ghostSendWithoutSound == 1), .checkbox(2, 0, "2", "Всегда", s.ghostSendWithoutSound == 2)] }, select: { s.ghostSendWithoutSound = Int($0) ?? 0 })
}

func dgAppearanceSettingsController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Оформление", entries: {
        var entries: [DGListEntry] = [
            .header(0, 0, "ОСНОВНОЕ"),
            .toggle(1, 0, "premiumStatuses", "Скрыть премиум статусы", s.hidePremiumStatuses, true),
            .toggle(2, 0, "customBackgrounds", "Отключить кастомные фоны", s.disableCustomBackgrounds, true),
            .toggle(3, 0, "hideStories", "Скрыть сторис", s.hideStories, true),
            .header(10, 1, "ПРИЛОЖЕНИЕ"), .appIcons(11, 1),
            .header(12, 2, "ОСТРОВ"), .islandStyles(13, 2, s.islandStyle),
            .header(20, 3, "ВКЛАДКИ"),
            .toggle(21, 3, "hideTabBar", "Скрыть панель вкладок", s.hideTabBar, true),
            .toggle(22, 3, "contacts", "Вкладка Контакты", s.showContactsTab, !s.hideTabBar),
            .toggle(23, 3, "calls", "Вкладка Звонки", s.showCallsTab, !s.hideTabBar),
            .toggle(24, 3, "wideTabBar", "Широкая Панель", s.wideTabBar, !s.hideTabBar),
            .header(30, 4, "ПРОФИЛЬ"),
            .toggle(31, 4, "profileId", "ID Профилей", s.showProfileId, true)
        ]
        if s.showProfileId {
            entries.append(.disclosure(37, 4, "dialogIdFormat", "Показывать ID диалога", s.dialogIdFormat == .botApi ? "Bot API" : "Telegram API"))
        }
        entries.append(contentsOf: [
            .toggle(32, 4, "dc", "Показывать дата-центр (DC)", s.showDc, true),
            .toggle(33, 4, "regDate", "Показывать дату регистрации", s.showRegistrationDate, true),
            .toggle(34, 4, "chatDate", "Показывать дату создания чата", s.showChatCreationDate, true),
            .toggle(35, 4, "mutualContact", "Показывать взаимный контакт", s.showMutualContact, true),
            .toggle(38, 4, "relativeOnlineTime", "Относительное время онлайна", s.relativeOnlineTime, true),
            .toggle(39, 4, "hidePhoneNumber", "Скрыть номер телефона", s.hidePhoneNumber, true),
            .header(40, 5, "ДРУГОЕ"),
            .toggle(41, 5, "disableAds", "Отключить рекламу", s.disableAds, true),
            .toggle(42, 5, "confirmCalls", "Подтверждение вызова", s.confirmCalls, true)
        ])
        return entries
    }, restartRequiredKeys: ["premiumStatuses", "hideStories", "hideTabBar", "contacts", "calls", "wideTabBar"], toggle: { key, value in
        switch key { case "premiumStatuses": s.hidePremiumStatuses = value; case "customBackgrounds": s.disableCustomBackgrounds = value; case "hideStories": s.hideStories = value; case "snow": s.forceSnow = value; case "hideTabBar": s.hideTabBar = value; case "contacts": s.showContactsTab = value; case "calls": s.showCallsTab = value; case "wideTabBar": s.wideTabBar = value; case "profileId": s.showProfileId = value; case "dc": s.showDc = value; case "regDate": s.showRegistrationDate = value; case "chatDate": s.showChatCreationDate = value; case "mutualContact": s.showMutualContact = value; case "relativeOnlineTime": s.relativeOnlineTime = value; case "hidePhoneNumber": s.hidePhoneNumber = value; case "confirmCalls": s.confirmCalls = value; case "disableAds": s.disableAds = value; default: break }
    }, select: { key in
        if key.hasPrefix("islandStyle:"), let value = Int(key.split(separator: ":").last ?? "") { s.islandStyle = value }
    }, open: { key in key == "dialogIdFormat" ? dgDialogIdFormatController(context: context) : nil })
}

private func dgDialogIdFormatController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "ID диалога", entries: {
        [.checkbox(0, 0, "0", "Telegram API", s.dialogIdFormat == .telegramApi),
         .checkbox(1, 0, "1", "Bot API", s.dialogIdFormat == .botApi)]
    }, select: { s.dialogIdFormat = $0 == "1" ? .botApi : .telegramApi })
}

func dgChatsSettingsController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Чаты", entries: {
        let hiddenCount = [1, 2, 4].filter { s.hiddenReactions & $0 != 0 }.count
        let transcription = dgTranscriptionBackendTitle(s.transcriptionBackend)
        let cameraTitle: String
        switch s.roundVideoCamera {
        case .front: cameraTitle = "Фронтальная"
        case .rear: cameraTitle = "Основная"
        case .ask: cameraTitle = "Спрашивать"
        }
        var result: [DGListEntry] = [
            .header(0, 0, "СТИКЕРЫ И ЭМОДЗИ"),
            .toggle(1, 0, "onlyAdded", "Показывать только добавленные стикеры", s.onlyAddedStickers, true),
            .toggle(2, 0, "recent", "Беск. недавние стикеры", s.infiniteRecentStickers, true),
            .disclosure(3, 0, "reactions", "Скрыть реакции", "\(hiddenCount)/3"),
            .header(10, 1, "СООБЩЕНИЯ"),
            .messagePreview(11, 1, s.removeMessageTails, s.showMessageSeconds, s.disableColoredReplies, s.editedIcon),
            .toggle(12, 1, "tails", "Убрать хвост у сообщений", s.removeMessageTails, true),
            .toggle(13, 1, "seconds", "Показывать секунды", s.showMessageSeconds, true),
            .toggle(14, 1, "replies", "Отключить цветные ответы", s.disableColoredReplies, true),
            .toggle(15, 1, "editedIcon", "Заменять «изменено» иконкой", s.editedIcon, true),
            .toggle(16, 1, "onlineIndicator", "Показывать индикатор онлайна", s.showOnlineIndicator, true),
            .toggle(17, 1, "greetingSticker", "Скрыть приветственный стикер", s.hideGreetingSticker, true),
            .toggle(18, 1, "mentionComma", "Запятая после упоминания", s.commaAfterMention, true),
            .toggle(19, 1, "pollResultsBeforeVoting", "Итоги до голосования", s.showPollResultsBeforeVoting, true),
            .header(20, 2, "ГОЛОС В ТЕКСТ"),
            .disclosure(21, 2, "transcription", "Сервис", transcription),
            .header(30, 3, "КАМЕРА"),
            .disclosure(31, 3, "camera", "Камера в кружках", cameraTitle),
            .toggle(32, 3, "rememberCamera", "Запоминать последнюю камеру", s.rememberRoundVideoCamera, true),
            .toggle(33, 3, "zoomSlider", "Слайдер зума", s.roundVideoZoomSlider, true),
            .toggle(34, 3, "staticZoom", "Статичный зум", s.staticRoundVideoZoom, true),
            .header(40, 4, "ВИДЕО"),
            .disclosure(41, 4, "doubleTapSeek", "Перемотка двойным нажатием", s.doubleTapSeekSeconds == 0 ? "Отключено" : "\(s.doubleTapSeekSeconds) сек."),
            .toggle(42, 4, "autoPause", "Авто пауза", s.autoPause, true),
            .disclosure(43, 4, "autoPauseMedia", "Приостанавливать", "\([1, 2, 4].filter { s.autoPauseMedia & $0 != 0 }.count)/3"),
            .header(50, 5, "ДРУГОЕ"),
            .toggle(51, 5, "hideArchive", "Скрывать архив из списка чатов", s.hideArchive, true)
        ]
        if s.hideArchive {
            result.append(.toggle(52, 5, "openArchiveOnPull", "Открывать архив при вытягивании", s.openArchiveOnPull, true))
        }
        result.append(contentsOf: [.header(60, 6, "СПИСОК ЧАТОВ"), .disclosure(61, 6, "chatListAppearance", "Внешний вид", "")])
        return result
    }, toggle: { key, value in
        switch key {
        case "onlyAdded": s.onlyAddedStickers = value
        case "recent": s.infiniteRecentStickers = value
        case "tails": s.removeMessageTails = value
        case "seconds": s.showMessageSeconds = value
        case "replies": s.disableColoredReplies = value
        case "editedIcon": s.editedIcon = value
        case "onlineIndicator": s.showOnlineIndicator = value
        case "greetingSticker": s.hideGreetingSticker = value
        case "mentionComma": s.commaAfterMention = value
        case "pollResultsBeforeVoting": s.showPollResultsBeforeVoting = value
        case "rememberCamera": s.rememberRoundVideoCamera = value
        case "zoomSlider": s.roundVideoZoomSlider = value
        case "staticZoom": s.staticRoundVideoZoom = value
        case "autoPause": s.autoPause = value
        case "hideArchive":
            s.hideArchive = value
            let _ = updateChatArchiveSettings(engine: context.engine, { current in
                var current = current
                current.isHiddenByDefault = value
                return current
            }).startStandalone()
        case "openArchiveOnPull": s.openArchiveOnPull = value
        default: break
        }
    }, open: { key in
        switch key {
        case "reactions": return dgHiddenReactionsController(context: context)
        case "transcription": return dgTranscriptionController(context: context)
        case "camera": return dgRoundVideoCameraController(context: context)
        case "autoPauseMedia": return dgAutoPauseMediaController(context: context)
        case "doubleTapSeek": return dgDoubleTapSeekController(context: context)
        case "chatListAppearance": return dgChatListAppearanceController(context: context)
        default: return nil
        }
    })
}

private func dgChatListAppearanceController(context: AccountContext) -> ViewController {
    let settings = DGSimpleSettings.shared
    return dgController(context: context, title: "Внешний вид", entries: {
        [
            .header(0, 0, "СПИСОК ЧАТОВ"),
            .chatListPreview(1, 0, settings.forceSnow, settings.chatListHideStatus, settings.chatListCenteredTitle, settings.chatListHideSearch, settings.chatListSenderAvatars, settings.chatListTitleMode.rawValue),
            .toggle(2, 0, "snow", "Снег", settings.forceSnow, true),
            .toggle(3, 0, "hideStatus", "Скрыть статус", settings.chatListHideStatus, true),
            .toggle(4, 0, "centerTitle", "Заголовок по центру", settings.chatListCenteredTitle, true),
            .toggle(5, 0, "hideSearch", "Скрыть строку поиска", settings.chatListHideSearch, true),
            .toggle(6, 0, "senderAvatars", "Мини-аватарки отправителей", settings.chatListSenderAvatars, true),
            .disclosure(7, 0, "titleMode", "Текст в заголовке", dgChatListTitleModeTitle(settings.chatListTitleMode))
        ]
    }, toggle: { key, value in
        switch key {
        case "snow": settings.forceSnow = value
        case "hideStatus": settings.chatListHideStatus = value
        case "centerTitle": settings.chatListCenteredTitle = value
        case "hideSearch": settings.chatListHideSearch = value
        case "senderAvatars": settings.chatListSenderAvatars = value
        default: break
        }
    }, open: { key in
        key == "titleMode" ? dgChatListTitleModeController(context: context) : nil
    })
}

private func dgChatListTitleModeTitle(_ mode: DGSimpleSettings.ChatListTitleMode) -> String {
    switch mode {
    case .donutgram: return "Donutgram"
    case .username: return "Юзернейм"
    case .nickname: return "Никнейм"
    case .chats: return "Чаты"
    }
}

private func dgChatListTitleModeController(context: AccountContext) -> ViewController {
    let settings = DGSimpleSettings.shared
    let modes: [DGSimpleSettings.ChatListTitleMode] = [.donutgram, .username, .nickname, .chats]
    return dgController(context: context, title: "Текст в заголовке", entries: {
        modes.enumerated().map { index, mode in
            .checkbox(Int32(index), 0, String(mode.rawValue), dgChatListTitleModeTitle(mode), settings.chatListTitleMode == mode)
        }
    }, select: { key in
        settings.chatListTitleMode = DGSimpleSettings.ChatListTitleMode(rawValue: Int(key) ?? 0) ?? .chats
    })
}

private func dgDoubleTapSeekController(context: AccountContext) -> ViewController {
    let settings = DGSimpleSettings.shared
    let values = [0, 5, 10, 15, 30]
    return dgController(context: context, title: "Перемотка двойным нажатием", entries: {
        values.enumerated().map { index, value in
            .checkbox(Int32(index), 0, String(value), value == 0 ? "Отключено" : "\(value) секунд", settings.doubleTapSeekSeconds == value)
        }
    }, select: { settings.doubleTapSeekSeconds = Int($0) ?? 15 })
}

private func dgRoundVideoCameraController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Камера в кружках", entries: {
        [.checkbox(0, 0, "0", "Фронтальная", s.roundVideoCamera == .front),
         .checkbox(1, 0, "1", "Основная", s.roundVideoCamera == .rear),
         .checkbox(2, 0, "2", "Спрашивать", s.roundVideoCamera == .ask)]
    }, select: { s.roundVideoCamera = DGSimpleSettings.RoundVideoCamera(rawValue: Int($0) ?? 0) ?? .front })
}

private func dgAutoPauseMediaController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Авто пауза", entries: {
        [.toggle(0, 0, "1", "Видео", s.autoPauseMedia & 1 != 0, true),
         .toggle(1, 0, "2", "Голосовых", s.autoPauseMedia & 2 != 0, true),
         .toggle(2, 0, "4", "Кружков", s.autoPauseMedia & 4 != 0, true)]
    }, toggle: { key, value in
        let bit = Int(key) ?? 0
        s.autoPauseMedia = value ? (s.autoPauseMedia | bit) : (s.autoPauseMedia & ~bit)
    })
}

func dgDownloadsSettingsController(context: AccountContext) -> ViewController {
    let settings = DGSimpleSettings.shared
    return dgController(context: context, title: "Скачивание", entries: {
        [.header(0, 0, "СКАЧИВАНИЕ"), .toggle(1, 0, "downloadTikTok", "Скачивать TikTok", settings.downloadTikTok, true), .toggle(2, 0, "downloadShorts", "Скачивать YT Shorts", settings.downloadYouTubeShorts, true), .toggle(3, 0, "signDownloads", "Подписывать", settings.signDownloadedMedia, true)]
    }, toggle: { key, value in
        switch key { case "downloadTikTok": settings.downloadTikTok = value; case "downloadShorts": settings.downloadYouTubeShorts = value; case "signDownloads": settings.signDownloadedMedia = value; default: break }
    })
}

private func dgTranscriptionBackendTitle(_ backend: DGSimpleSettings.TranscriptionBackend) -> String {
    switch backend {
    case .auto: return "Авто"
    case .telegram: return "Telegram"
    case .apple: return "Apple"
    }
}

private func dgTranscriptionController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Голос в текст", entries: {
        let backend = s.transcriptionBackend
        let info: String
        switch backend {
        case .auto: info = "Telegram, пока он может расшифровать сообщение сам — с Premium или бесплатными попытками. Иначе Apple."
        case .telegram: info = "Telegram использует облачный сервис распознавания."
        case .apple: info = "Apple распознаёт речь на устройстве, а если язык не поддерживается — на серверах Apple."
        }
        return [.checkbox(0, 0, "auto", "Авто", backend == .auto), .checkbox(1, 0, "telegram", "Telegram", backend == .telegram), .checkbox(2, 0, "apple", "Apple", backend == .apple), .info(3, 0, info)]
    }, select: { s.transcriptionBackend = DGSimpleSettings.TranscriptionBackend(rawValue: $0) ?? .auto })
}

private func dgHiddenReactionsController(context: AccountContext) -> ViewController {
    let s = DGSimpleSettings.shared
    return dgController(context: context, title: "Скрыть реакции", entries: { [.toggle(0, 0, "1", "Каналы", s.hiddenReactions & 1 != 0, true), .toggle(1, 0, "2", "Группы", s.hiddenReactions & 2 != 0, true), .toggle(2, 0, "4", "Личные чаты", s.hiddenReactions & 4 != 0, true)] }, toggle: { key, value in
        let mask = Int(key) ?? 0
        s.hiddenReactions = value ? (s.hiddenReactions | mask) : (s.hiddenReactions & ~mask)
    })
}

func dgSupportController(context: AccountContext) -> ViewController {
    dgController(context: context, title: "Поддержка", entries: { [.header(0, 0, "ПОДДЕРЖКА"), .info(1, 0, "Раздел подготовлен для ссылок на поддержку и информацию о Donutgram.")] })
}

public func dgSettingsControllerForLink(context: AccountContext, page: String, key: String) -> ViewController? {
    let makeController: (() -> ViewController)?
    switch page {
    case "root": makeController = { dgSettingsController(context: context) }
    case "general": makeController = { dgSpySettingsController(context: context) }
    case "ghost": makeController = { dgGhostSettingsController(context: context) }
    case "ghost-options": makeController = { dgGhostOptionsController(context: context) }
    case "silent": makeController = { dgSilentModeController(context: context) }
    case "appearance": makeController = { dgAppearanceSettingsController(context: context) }
    case "dialog-id": makeController = { dgDialogIdFormatController(context: context) }
    case "chats": makeController = { dgChatsSettingsController(context: context) }
    case "camera": makeController = { dgRoundVideoCameraController(context: context) }
    case "auto-pause": makeController = { dgAutoPauseMediaController(context: context) }
    case "downloads": makeController = { dgDownloadsSettingsController(context: context) }
    case "transcription": makeController = { dgTranscriptionController(context: context) }
    case "reactions": makeController = { dgHiddenReactionsController(context: context) }
    case "visual-id": makeController = { dgVisualIdController(context: context) }
    case "visual-rating": makeController = { dgVisualRatingController(context: context) }
    case "visual-usernames": makeController = { dgVisualUsernamesController(context: context) }
    case "visual-phone": makeController = { dgVisualPhoneController(context: context) }
    case "support": makeController = { dgSupportController(context: context) }
    default: makeController = nil
    }
    guard let makeController else { return nil }
    let focusKey: String
    if page == "chats" && key == "openArchiveOnPull" && !DGSimpleSettings.shared.hideArchive {
        focusKey = "hideArchive"
    } else if page == "appearance" && key == "dialogIdFormat" && !DGSimpleSettings.shared.showProfileId {
        focusKey = "profileId"
    } else {
        focusKey = key
    }
    dgPrepareSettingLinkFocus(page: page, key: focusKey)
    return makeController()
}
