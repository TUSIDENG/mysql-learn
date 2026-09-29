-- =====================================================================
-- 05-transaction.sql —— 事务、隔离级别、锁、锁超时、死锁
-- 本脚本：单会话即可执行（所有需要执行的 SQL 均未注释）。
-- 双会话并发演示：请同时运行同目录两个配套脚本
--   05a-demo-session-a.sql   （会话A）
--   05b-demo-session-b.sql   （会话B）
-- 用法（两个终端同时启动，约 40 秒自动跑完）：
--   docker exec -i mysql-learn-84 mysql -uroot -proot123 --force < 05a-demo-session-a.sql
--   docker exec -i mysql-learn-84 mysql -uroot -proot123 --force < 05b-demo-session-b.sql
-- 兼容性：通用 5.7 ~ 26.x；[8.0+] 语法已单独标注，5.7 请跳过
-- =====================================================================
USE mysql_learn;

-- 每次重跑时先清理演练表
DROP TABLE IF EXISTS stock;
DROP TABLE IF EXISTS account;

-- ---------------------------------------------------------------------
-- 账户表（事务/转账演练）
-- ---------------------------------------------------------------------
CREATE TABLE account (
    acct_id INT UNSIGNED NOT NULL,
    owner   VARCHAR(20)  NOT NULL,
    balance DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (acct_id)
) ENGINE = InnoDB;

INSERT INTO account VALUES (1, '张三', 1000.00), (2, '李四', 1000.00);

-- ---------------------------------------------------------------------
-- 库存表（锁/死锁演练），status 上无索引，用于演示"锁没走索引"
-- ---------------------------------------------------------------------
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
-- 一、事务 ACID（InnoDB 支持；MyISAM 不支持事务）
-- =====================================================================
-- A 原子性：事务内操作要么全成功要么全回滚（undo log）
-- C 一致性：事务前后数据满足约束/业务规则
-- I 隔离性：并发事务互不干扰，由隔离级别 + 锁/MVCC 实现
-- D 持久性：提交后宕机也不丢（redo log + 刷盘机制）

-- =====================================================================
-- 二、事务控制语句
-- =====================================================================
-- 经典转账：张三给李四转 100，必须同成功同失败
START TRANSACTION;                       -- 或 BEGIN
UPDATE account SET balance = balance - 100 WHERE acct_id = 1;
UPDATE account SET balance = balance + 100 WHERE acct_id = 2;
COMMIT;                                  -- 提交后改动永久生效
SELECT * FROM account;

-- 回滚演练
START TRANSACTION;
UPDATE account SET balance = 0 WHERE acct_id = 1;
SELECT * FROM account;                   -- 会话内看到 0
ROLLBACK;                                -- 撤销
SELECT * FROM account;                   -- 恢复原值

-- 自动提交：MySQL 默认 autocommit=1，每条语句自成事务
SHOW VARIABLES LIKE 'autocommit';

-- 部分回滚：SAVEPOINT 保存点
START TRANSACTION;
UPDATE account SET balance = balance + 50 WHERE acct_id = 1;
SAVEPOINT sp1;
UPDATE account SET balance = balance + 999 WHERE acct_id = 1;
ROLLBACK TO SAVEPOINT sp1;               -- 只撤销到保存点
COMMIT;
SELECT * FROM account;

-- =====================================================================
-- 三、隔离级别
-- =====================================================================
-- 并发可能出现的问题：
--   脏读：读到别的事务未提交的数据
--   不可重复读：同一事务两次读同一行，结果不同（被别的事务 UPDATE 并提交）
--   幻读：同一事务两次范围查询，行数不同（被别的事务 INSERT/DELETE）
--
-- SQL 标准四级隔离：
--                    脏读   不可重复读  幻读
-- READ UNCOMMITTED    可能    可能       可能
-- READ COMMITTED      避免    可能       可能
-- REPEATABLE READ     避免    避免       InnoDB 基本避免（MVCC+间隙锁）
-- SERIALIZABLE        避免    避免       避免（普通 SELECT 隐式加 S 锁）
--
-- MySQL 默认：REPEATABLE READ（5.7/8.x/26.x 都是）
-- Oracle/PostgreSQL 默认 READ COMMITTED

-- 查看隔离级别（版本差异）
SELECT @@transaction_isolation;          -- [8.0+ 变量名]
-- SELECT @@tx_isolation;                 -- [5.7 变量名]

-- 设置隔离级别（可加 GLOBAL / SESSION），演示后改回默认 RR
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT @@transaction_isolation AS now_is_rc;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT @@transaction_isolation AS now_is_rr;

-- 不可重复读（RC）与可重复读（RR）的双会话完整演示
-- 见 05a / 05b 脚本【场景1】

-- =====================================================================
-- 四、InnoDB 锁体系
-- =====================================================================
-- 1) 按模式分：
--    S 共享锁（读锁）：S 与 S 兼容，与 X 互斥
--    X 排他锁（写锁）：X 与 S/X 都互斥
--    普通 SELECT 是快照读，不加锁；UPDATE/DELETE/INSERT 自动加 X 锁
--
-- 2) 按粒度分：
--    行锁（Record Lock）：锁索引记录
--    间隙锁（Gap Lock）：锁索引记录之间的间隙，防插入（仅 RR，RC 下基本无间隙锁）
--    Next-Key Lock：行锁 + 前面的间隙锁，InnoDB RR 默认加锁单位
--    表锁：LOCK TABLES、DDL、MDL（元数据锁）；AUTO-INC 锁
--
-- 3) 快照读 vs 当前读：
--    快照读：普通 SELECT，读 MVCC 历史版本，不加锁
--    当前读：读最新版本并加锁
--            SELECT ... FOR UPDATE（X）
--            SELECT ... FOR SHARE （S，[8.0+] 标准写法）
--            SELECT ... LOCK IN SHARE MODE（S，5.7/8.0 旧写法）
--            INSERT/UPDATE/DELETE 本身也是当前读
--
-- 意向锁（IS/IX）：表级，加行锁前自动加，让"加表锁"快速判断是否冲突
-- MDL：事务内访问表即持有 MDL 读锁；DDL 要 MDL 写锁。
--      长事务会让 DDL 等 MDL，并进一步阻塞后续所有查询（MDL 等待风暴）

-- 锁定读：当前会话内即可验证 FOR UPDATE 持锁/提交释放
START TRANSACTION;
SELECT * FROM account WHERE acct_id = 1 FOR UPDATE;
SELECT * FROM account WHERE acct_id = 2 FOR SHARE;
COMMIT;

-- 行锁加在"索引记录"上：无索引列更新会锁很多行
-- 双会话完整演示（含加索引前后对比）见 05a / 05b 脚本【场景4】【场景5】

-- 间隙锁 / Next-Key Lock（RR 防幻读）
-- 双会话完整演示见 05a / 05b 脚本【场景6】

-- 表锁（InnoDB 日常不要用，演练）
LOCK TABLES account READ;
SELECT * FROM account;
UNLOCK TABLES;

-- =====================================================================
-- 五、锁等待与锁超时（错误码 1205，SQLSTATE HY000）
-- =====================================================================
-- 原理：事务 B 申请的锁被事务 A 持有且不兼容 → B 进入锁等待队列；
--       等待超过 innodb_lock_wait_timeout（默认 50 秒）后报 1205；
--       超时只回滚"当前这条语句"（不是整个事务），应用需决定重试还是回滚。

SHOW VARIABLES LIKE 'innodb_lock_wait_timeout';
SHOW VARIABLES LIKE 'lock_wait_timeout';

-- 双会话完整复现 1205 见 05a / 05b 脚本【场景3】

-- =====================================================================
-- 六、死锁（错误码 1213，SQLSTATE 40001）
-- =====================================================================
-- 原理：两个及以上事务互相持有对方需要的锁，形成等待环。
-- InnoDB 主动死锁检测 innodb_deadlock_detect=ON（默认）：
--   发现环立即选"代价较小"的事务整个回滚，报 1213；
--   40001 语义即"请重试整个事务"。
-- 高并发热点行下检测开销接近 O(n²)，必要时才关闭检测并以
-- innodb_lock_wait_timeout 兜底（需配合重试，谨慎）。

SHOW VARIABLES LIKE 'innodb_deadlock_detect';

-- 双会话完整复现 1213 见 05a / 05b 脚本【场景7】

-- =====================================================================
-- 七、诊断：查谁在等谁、看死锁日志
-- =====================================================================
-- 当前 InnoDB 事务
SELECT trx_id, trx_state, trx_started, trx_rows_locked, trx_query
FROM information_schema.INNODB_TRX;

-- [8.0+] 锁等待关系（谁 blocking 谁）
SELECT
    w.REQUESTING_THREAD_ID AS waiting_thread,
    r.PROCESSLIST_ID       AS waiting_conn_id,
    w.BLOCKING_THREAD_ID   AS blocking_thread,
    b.PROCESSLIST_ID       AS blocking_conn_id
FROM performance_schema.data_lock_waits w
JOIN performance_schema.threads b ON b.THREAD_ID = w.BLOCKING_THREAD_ID
JOIN performance_schema.threads r ON r.THREAD_ID = w.REQUESTING_THREAD_ID;

-- [8.0+] 更详细的锁信息
SELECT ENGINE, THREAD_ID, LOCK_MODE, LOCK_TYPE, LOCK_DATA
FROM performance_schema.data_locks;

-- [5.7 专用] 老表（8.0 起移除，勿在 8.x 执行）
-- SELECT r.trx_id AS waiting_trx, r.trx_mysql_thread_id AS waiting_thread,
--        b.trx_id AS blocking_trx, b.trx_mysql_thread_id AS blocking_thread
-- FROM information_schema.INNODB_LOCK_WAITS w
-- JOIN information_schema.INNODB_TRX b ON b.trx_id = w.blocking_trx_id
-- JOIN information_schema.INNODB_TRX r ON r.trx_id = w.requesting_trx_id;

-- 应急：KILL 掉持锁最久的会话（用上面查出的 blocking_conn_id）
-- KILL <blocking_conn_id>;

-- 最近一次死锁详情（LATEST DETECTED DEADLOCK 段）
SHOW ENGINE INNODB STATUS;

-- [8.0+] 诊断辅助开关
-- SET GLOBAL innodb_status_output_locks = ON;   -- InnoDB 状态输出所有锁
-- SET GLOBAL innodb_print_all_deadlocks = ON;   -- 死锁写入错误日志

-- 状态计数：监控告警用
SHOW GLOBAL STATUS LIKE 'Innodb_deadlocks';
SHOW GLOBAL STATUS LIKE 'Innodb_row_lock_waits';
SHOW GLOBAL STATUS LIKE 'Innodb_row_lock_time_avg';

-- =====================================================================
-- 练习
-- 1. 同时跑 05a / 05b，观察【场景1】RC 与 RR 下两次读结果差异
-- 2. 观察【场景2】FOR UPDATE 阻塞与【场景3】1205 锁超时
-- 3. 在【场景7】看到 1213，并用 SHOW ENGINE INNODB STATUS 找到死锁日志
-- 4. 对比【场景4】【场景5】无索引/有索引时的锁范围差异
-- 5. 阅读同目录 05-transaction.md，整理应用侧重试与避锁规范
-- =====================================================================
