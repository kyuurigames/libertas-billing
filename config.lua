Config = {}

-- キー設定
Config.OpenKey = 'F7' -- デフォルトキー
Config.KeyMappingName = 'open_billing' -- キーマッピング名

-- 近くのプレイヤー検索距離（メートル）
Config.NearbyPlayerDistance = 5.0 -- 5メートル以内

-- 支払い期限（日数）
Config.PaymentDeadline = 7 -- 7日間

-- 滞納通知の間隔（分）
Config.OverdueNotificationInterval = 30 -- 30分ごと

-- 最大請求金額
Config.MaxBillAmount = 1000000 -- 100万

-- 最小請求金額
Config.MinBillAmount = 1 -- 1円

-- 管理者権限（QB-Coreの職業名またはメタデータグループ名）
Config.AdminGroups = {
    'god',
    'admin',
    'moderator'
}

-- 管理者職業（job名での管理者判定）
Config.AdminJobs = {
    'admin',
    'management'
}

-- 警察の職業
Config.PoliceJobs = {
    'police',
    'bcso',
    'sast',
    'sheriff'
}

-- 支払い手数料（パーセント）
Config.PaymentFee = 0 -- 0%（手数料なし）

-- デバッグモード
Config.Debug = false

-- 通知設定
Config.Notifications = {
    ['bill_sent'] = '請求書を送信しました',
    ['bill_received'] = '新しい請求書を受け取りました',
    ['bill_paid'] = '請求書の支払いが完了しました',
    ['payment_received'] = '支払いを受け取りました',
    ['insufficient_funds'] = '残高が不足しています',
    ['bill_not_found'] = '請求書が見つかりません',
    ['invalid_amount'] = '無効な金額です',
    ['invalid_player'] = 'プレイヤーが見つかりません',
    ['overdue_reminder'] = '未払いの請求書があります',
    ['no_permission'] = '権限がありません',
    ['no_nearby_players'] = '近くにプレイヤーがいません',
    ['player_too_far'] = 'プレイヤーが遠すぎます'
}