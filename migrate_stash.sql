INSERT INTO inventories (identifier, items)

SELECT
  stash,
  items
FROM
  stashitems;