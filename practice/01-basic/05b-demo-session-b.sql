-- =====================================================================
-- 05b-demo-session-b.sql —— 双会话并发演示【会话B】
-- 与 05a-demo-session-a.sql 同时启动，靠 DO SLEEP 对齐时间轴。
-- 必须加 --force：场景3 的 1205、场景7 的 1213 是预期错误。
--
--   docker exec -i mysql-learn-84 mysql -uroot -proot123 --force \
--     < practice/01-basic/05b-demo-session-b.sql
-- =====================================================================
USE mysql_learn;

-- A 启动时会重建表，等待其完成
DO SLEEP(2);

-- =====================================================================
-- 场景1：RC 不可重复读  vs  RR 可重复读
-- =====================================================================

-- ---- 1a. RC：在 A 两次读之间把值改为 5000 并提交（t≈3，A 第二次读在 t=5）----
SELECT '=== B 场景1a RC：更新 id=1 为 5000 并提交 ===' AS step;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
UPDATE account SET balance = 5000.00 WHERE acct_id = 1;
COMMIT;

-- ---- 1b. RR：在 A 事务期间把值改为 8000 并提交（t≈8，A 窗口 6~11）----
DO SLEEP(5);
SELECT '=== B 场景1b RR：更新 id=1 为 8000 并提交（A 的快照不受影响）===' AS step;
START TRANSACTION;
UPDATE account SET balance = 8000.00 WHERE acct_id = 1;
COMMIT;

-- =====================================================================
-- 场景2：A 持有 FOR UPDATE 期间（t13~16），B 在 t14 请求，被阻塞至 t16
-- =====================================================================
DO SLEEP(6);
SELECT '=== B 场景2：请求 id=1 写锁（被 A 阻塞，A 提交后返回）===' AS step;
START TRANSACTION;
SELECT balance AS blocked_for_update FROM account WHERE acct_id = 1 FOR UPDATE;
COMMIT;

-- =====================================================================
-- 场景3：锁超时 1205
-- B 在 t19 请求（A 持锁 t18~23），超时设 3 秒 → t22 报 1205，早于 A 提交
-- =====================================================================
DO SLEEP(3);
SET SESSION innodb_lock_wait_timeout = 3;
SELECT '=== B 场景3：请求 id=1 写锁，3 秒后将报 ERROR 1205 ===' AS step;
START TRANSACTION;
UPDATE account SET balance = balance WHERE acct_id = 1;
-- 若能执行到这里说明已拿到锁；本次设计应在上面的 UPDATE 处报 1205
ROLLBACK;
SELECT '=== B 场景3：1205 只回滚单条语句，这里显式 ROLLBACK 清理事务 ===' AS step;

-- =====================================================================
-- 场景4：A 无索引更新 status=0（t25~27），B 在 t26 改 status=1 的行也被阻塞
-- =====================================================================
DO SLEEP(4);
SELECT '=== B 场景4：改 sku_id=1(status=1)，无索引时仍被 A 阻塞 ===' AS step;
UPDATE stock SET qty = qty + 1 WHERE sku_id = 1;
SELECT '=== B 场景4：更新在 A 提交后才完成 ===' AS step;

-- =====================================================================
-- 场景5：加索引后（ALTER 在 t29），B 在 t31 改 status=0 的行，与 A(status=1) 不冲突
-- =====================================================================
DO SLEEP(4);
SELECT '=== B 场景5：改 status=0 的行（有索引，应立即成功不被A阻塞）===' AS step;
UPDATE stock SET qty = qty + 1 WHERE status = 0;
SELECT * FROM stock;

-- =====================================================================
-- 场景6：A 间隙锁窗口 t35~38，B 在 t36 插入新行，被阻塞至 t38
-- =====================================================================
DO SLEEP(5);
SELECT '=== B 场景6：插入 sku_id=10 的新行（被间隙锁阻塞，A提交后完成）===' AS step;
INSERT INTO stock (sku_id, sku_name, qty, status) VALUES (10, '摄像头', 5, 1);
SELECT * FROM stock WHERE sku_id = 10;

-- =====================================================================
-- 场景7：死锁 1213
-- t42 与 A 同时先锁 id=2，t44 再请求 id=1（与 A 反向）→ 成环
-- =====================================================================
DO SLEEP(4);
SELECT '=== B 场景7：先锁 id=2 ===' AS step;
START TRANSACTION;
UPDATE account SET balance = balance - 1 WHERE acct_id = 2;
DO SLEEP(2);
SELECT '=== B 场景7：再请求 id=1（成环 → 1213；若 B 被回滚则事务已结束）===' AS step;
UPDATE account SET balance = balance - 1 WHERE acct_id = 1;
COMMIT;

DO SLEEP(1);
SELECT '=== B 场景7：最终账户状态 ===' AS step;
SELECT * FROM account;

DO SLEEP(1);
SELECT '=== 会话B 全部场景结束 ===' AS step;
