-- =====================================================================
-- 05a-demo-session-a.sql —— 双会话并发演示【会话A】
-- 与 05b-demo-session-b.sql 同时启动，靠 DO SLEEP 对齐时间轴，
-- 约 70 秒自动跑完 7 个场景（含 1205 锁超时、1213 死锁）。
--
-- 运行方式（两个终端，先确认已执行过 00-sample-schema.sql）：
--   docker exec -i mysql-learn-84 mysql -uroot -proot123 --force \
--     < practice/01-basic/05a-demo-session-a.sql
--   docker exec -i mysql-learn-84 mysql -uroot -proot123 --force \
--     < practice/01-basic/05b-demo-session-b.sql
-- --force 必须加：场景3 的 1205、场景7 的 1213 是预期错误，要继续往下跑。
-- =====================================================================
USE mysql_learn;

-- 重置演练数据，保证可重复执行（B 在 t=2 后才访问表，此处 DDL 已完成）
DROP TABLE IF EXISTS stock;
DROP TABLE IF EXISTS account;

CREATE TABLE account (
    acct_id INT UNSIGNED NOT NULL,
    owner   VARCHAR(20)  NOT NULL,
    balance DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (acct_id)
) ENGINE = InnoDB;
INSERT INTO account VALUES (1, '张三', 1000.00), (2, '李四', 1000.00);

CREATE TABLE stock (
    sku_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
    sku_name VARCHAR(50) NOT NULL,
    qty     INT          NOT NULL DEFAULT 0,
    status  TINYINT      NOT NULL DEFAULT 1 COMMENT '1在售 0下架',
    PRIMARY KEY (sku_id)
) ENGINE = InnoDB;
INSERT INTO stock (sku_name, qty, status) VALUES
    ('鼠标', 100, 1),
    ('键盘', 50,  1),
    ('显示器', 10, 0);

-- =====================================================================
-- 场景1：RC 不可重复读  vs  RR 可重复读
-- =====================================================================

-- ---- 1a. READ COMMITTED：A 两次读之间 B 提交修改 → 读到不同结果 ----
SELECT '=== A 场景1a RC：开启事务，第一次读（期望1000）===' AS step;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT balance AS rc_read_1 FROM account WHERE acct_id = 1;
DO SLEEP(5);
SELECT '=== A 场景1a RC：第二次读（B已提交5000，期望5000→不可重复读）===' AS step;
SELECT balance AS rc_read_2 FROM account WHERE acct_id = 1;
COMMIT;

-- ---- 1b. REPEATABLE READ：B 在 A 事务期间提交，A 仍读快照值 ----
DO SLEEP(1);
SELECT '=== A 场景1b RR：开启事务，第一次读（期望5000）===' AS step;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT balance AS rr_read_1 FROM account WHERE acct_id = 1;
DO SLEEP(5);
SELECT '=== A 场景1b RR：第二次读（B已提交8000，仍期望5000→可重复读）===' AS step;
SELECT balance AS rr_read_2 FROM account WHERE acct_id = 1;
COMMIT;

-- =====================================================================
-- 场景2：FOR UPDATE 锁定读，B 的加锁请求被阻塞，A 提交后才获得锁
-- =====================================================================
DO SLEEP(2);
SELECT '=== A 场景2：持有 id=1 的 FOR UPDATE 锁 3 秒 ===' AS step;
START TRANSACTION;
SELECT acct_id, owner, balance FROM account WHERE acct_id = 1 FOR UPDATE;
DO SLEEP(3);
COMMIT;
SELECT '=== A 场景2：已提交，B 应随即获得锁 ===' AS step;

-- =====================================================================
-- 场景3：锁超时 1205（A 持锁 5 秒，B 超时设为 3 秒 → B 报 1205）
-- =====================================================================
DO SLEEP(2);
SELECT '=== A 场景3：持有 id=1 写锁 5 秒（B 将在第3秒报1205）===' AS step;
START TRANSACTION;
UPDATE account SET balance = balance WHERE acct_id = 1;
DO SLEEP(5);
COMMIT;
SELECT '=== A 场景3：已提交 ===' AS step;

-- =====================================================================
-- 场景4：更新没走索引 → 锁很多行（status 无索引）
-- A 用 status=0 更新，B 改 status=1 的 sku_id=1 也被阻塞
-- =====================================================================
DO SLEEP(2);
SELECT '=== A 场景4：无索引更新 status=0，锁住全部扫描行 ===' AS step;
START TRANSACTION;
UPDATE stock SET qty = qty - 1 WHERE status = 0;
DO SLEEP(2);
COMMIT;
SELECT '=== A 场景4：已提交，B 的更新此时才完成 ===' AS step;

-- =====================================================================
-- 场景5：给 status 加索引后，B 改不匹配的行不再被阻塞
-- =====================================================================
DO SLEEP(2);
ALTER TABLE stock ADD INDEX idx_status (status);
SELECT '=== A 场景5：已加 idx_status，按 status=1 更新只锁匹配行 ===' AS step;
DO SLEEP(2);
START TRANSACTION;
UPDATE stock SET qty = qty - 1 WHERE status = 1;
DO SLEEP(2);
COMMIT;
SELECT '=== A 场景5：已提交（B 改 status=0 的行应早已成功）===' AS step;

-- =====================================================================
-- 场景6：间隙锁/Next-Key Lock（RR）
-- A 锁定 sku_id>2，B 插入新行被阻塞，直到 A 提交
-- =====================================================================
DO SLEEP(2);
SELECT '=== A 场景6：SELECT ... WHERE sku_id>2 FOR UPDATE，锁(2,+∞) ===' AS step;
START TRANSACTION;
SELECT * FROM stock WHERE sku_id > 2 FOR UPDATE;
DO SLEEP(3);
COMMIT;
SELECT '=== A 场景6：已提交，B 的插入此时才完成 ===' AS step;

-- =====================================================================
-- 场景7：死锁 1213（交叉更新，加锁顺序相反，InnoDB 立即回滚一方）
-- =====================================================================
DO SLEEP(2);
-- 双方对齐后重置余额，保证死锁演示结果确定
UPDATE account SET balance = 1000.00;
DO SLEEP(2);
SELECT '=== A 场景7：先锁 id=1 ===' AS step;
START TRANSACTION;
UPDATE account SET balance = balance - 1 WHERE acct_id = 1;
DO SLEEP(2);
SELECT '=== A 场景7：再请求 id=2（与 B 成环 → 1213，一方被回滚）===' AS step;
UPDATE account SET balance = balance - 1 WHERE acct_id = 2;
DO SLEEP(1);
COMMIT;

DO SLEEP(1);
SELECT '=== A 场景7：最终账户状态 ===' AS step;
SELECT * FROM account;

DO SLEEP(1);
SELECT '=== 会话A 全部场景结束 ===' AS step;
