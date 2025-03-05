CREATE TABLE IF NOT EXISTS `inventories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(255) NOT NULL,
  `items` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`items`)),
  PRIMARY KEY (`identifier`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `shop_stock` (
	`id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
	`shop_name` VARCHAR(50) NOT NULL,
	`item_name` VARCHAR(50) NOT NULL,
	`stock` INT(11) UNSIGNED NOT NULL,
	PRIMARY KEY (`id`),
	UNIQUE INDEX `shop_name_item_name` (`shop_name`, `item_name`)
)
ENGINE=InnoDB;
