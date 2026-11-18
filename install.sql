-- All tables are created automatically on first start; included for manual installs.
CREATE TABLE IF NOT EXISTS `inventories` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(100) NOT NULL,
    `items` LONGTEXT NULL,
    PRIMARY KEY (`identifier`),
    KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `shop_stock` (
    `shop_name` VARCHAR(100) NOT NULL,
    `item_name` VARCHAR(100) NOT NULL,
    `stock` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`shop_name`, `item_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `inventory_stash_log` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `stash` VARCHAR(100) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL DEFAULT '',
    `name` VARCHAR(100) NOT NULL DEFAULT '',
    `action` VARCHAR(8) NOT NULL,
    `item` VARCHAR(100) NOT NULL,
    `amount` INT NOT NULL DEFAULT 1,
    `time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `stash_idx` (`stash`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `inventory_drops` (
    `id` VARCHAR(64) NOT NULL,
    `coords` VARCHAR(120) NOT NULL,
    `items` LONGTEXT NULL,
    `touched` INT NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
