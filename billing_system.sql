-- 請求書システム用データベーステーブル
-- MySQL/MariaDB用

CREATE TABLE IF NOT EXISTS `billing_system` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `sender_citizenid` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
    `receiver_citizenid` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
    `amount` int(11) NOT NULL,
    `reason` text COLLATE utf8mb4_general_ci NOT NULL,
    `status` enum('unpaid','paid') COLLATE utf8mb4_general_ci DEFAULT 'unpaid',
    `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
    `paid_at` timestamp NULL DEFAULT NULL,
    `due_date` timestamp NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_receiver` (`receiver_citizenid`),
    KEY `idx_sender` (`sender_citizenid`),
    KEY `idx_status` (`status`),
    KEY `idx_due_date` (`due_date`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- インデックスの最適化（パフォーマンス向上）
ALTER TABLE `billing_system` ADD INDEX `idx_receiver_status` (`receiver_citizenid`, `status`);
ALTER TABLE `billing_system` ADD INDEX `idx_sender_status` (`sender_citizenid`, `status`);
ALTER TABLE `billing_system` ADD INDEX `idx_status_due_date` (`status`, `due_date`);

-- 既存テーブルの照合順序を修正（既にテーブルが存在する場合）
ALTER TABLE `billing_system` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;