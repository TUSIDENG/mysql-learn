-- =====================================================================
-- 05-transaction.sql —— 事务、隔离级别、锁
-- 建议开两个 mysql 客户端会话，分别执行【会话A】【会话B】体会并发
-- =====================================================================
USE mysql_learn;

-- 准备一张账户表
DROP TABLE IF EXISTS account;
CREATE TABLE account (
    acct_id INT UNSIGNED NOT NULL,
    owner   VARCHAR(20) NOT NULL,
    balance DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (acct_id)
) ENGINE = InnoDB;

INSERT INTO account VALUES (1, '张三', 1000.00), (2, '李四', 1000.00);

-- =====================================================================
-- 一、事务 ACID（InnoDB 支持；MyISAM 不支持事务）
-- =====================================================================
-- A 原子性：一个事务内操作要么全成功要么全回滚
-- C 一致性：事务前后数据满足约束/业务规则
-- I 隔离性：并发事务互不干扰（由隔离级别决定程度）
-- D 持久性：提交后宕机也不丢（redo log + 刷盘机制保证）

-- =====================================================================
-- 二、事务控制语句
-- =====================================================================
-- 经典转账：张三给李四转 100，必须同成功同失败
START TRANSACTION;                       -- 或 BEGIN
UPDATE account SET balance = balance - 100 WHERE acct_id = 1;
UPDATE account SET balance = balance + 100 WHERE acct_id = 2;
-- 中途检查：SELECT * FROM account;
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
-- SET autocommit = 0;  -- 关闭后需手动 COMMIT/ROLLBACK

-- 部分回滚：SAVEPOINT 保存点
START TRANSACTION;
UPDATE account SET balance = balance + 50 WHERE acct_id = 1;
SAVEPOINT sp1;
UPDATE account SET balance = balance + 999 WHERE acct_id = 1;
ROLLBACK TO SAVEPOINT sp1;   -- 只撤销到保存点
COMMIT;

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
-- SERIALIZABLE        避免    避免       避免
--
-- MySQL 默认：REPEATABLE READ（5.7/8.x 都是）
-- Oracle/PostgreSQL 默认 READ COMMITTED

-- 查看隔离级别
SELECT @@transaction_isolation;          -- [8.0+ 变量名]
-- SELECT @@tx_isolation;                 -- [5.7 变量名]

-- 设置（可加 GLOBAL / SESSION）
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;  -- 改回默认

-- ---------------------------------------------------------------------
-- 【演示：不可重复读】隔离级别设为 READ COMMITTED
-- 会话A:                                  会话B:
-- START TRANSACTION;
-- SELECT balance FROM account WHERE acct_id=1;
--                                         START TRANSACTION;
--                                         UPDATE account SET balance=5000
--                                           WHERE acct_id=1;
--                                         COMMIT;
-- SELECT balance FROM account WHERE acct_id=1;  -- 两次结果不同！
-- COMMIT;
-- 在 REPEATABLE READ 下，第二次仍读到事务开始时的快照（MVCC）
-- ---------------------------------------------------------------------

-- =====================================================================
-- 四、锁
-- =====================================================================

-- 1) 读锁（共享 S）/ 写锁（排他 X）
--    普通 SELECT 不加锁（快照读）；UPDATE/DELETE/INSERT 自动加 X 锁

-- 2) 锁定读（当前读，手动加锁）
-- SELECT ... FOR UPDATE;    -- 加 X 锁，其他事务不能改也不能 FOR UPDATE
-- SELECT ... LOCK IN SHARE MODE;   -- [5.7/8.0 写法]
-- SELECT ... FOR SHARE;            -- [8.0+ 标准写法]

-- 会话A:
-- START TRANSACTION;
-- SELECT * FROM account WHERE acct_id = 1 FOR UPDATE;
-- 会话B 此时执行会阻塞，直到 A COMMIT:
-- UPDATE account SET balance = balance - 1 WHERE acct_id = 1;
-- 会话A: COMMIT;

-- 3) 行锁是加在索引上的！没走索引会锁很多行（甚至近似锁表）
--    这是 MySQL 锁最容易踩的坑，优化章节展开

-- 4) 间隙锁/Next-Key Lock（RR 级别）：锁住记录之间的间隙，防止插入，解决幻读
--    SELECT * FROM account WHERE acct_id > 1 FOR UPDATE;
--    其他事务 INSERT acct_id=3 会被阻塞

-- 5) 表锁
LOCK TABLES account READ;    -- 只读，自己也不能写
UNLOCK TABLES;
-- LOCK TABLES account WRITE;  -- 独占读写
-- InnoDB 中尽量使用行级锁，避免表锁影响并发

-- 6) 死锁：两个事务互相等待对方的锁
-- ---------------------------------------------------------------------
-- 会话A:                              会话B:
-- START TRANSACTION;                  START TRANSACTION;
-- UPDATE account SET balance=balance-1 WHERE acct_id=1;
--                                     UPDATE account SET balance=balance-1 WHERE acct_id=2;
-- UPDATE account SET balance=balance-1 WHERE acct_id=2; -- 等B
--                                     UPDATE account SET balance=balance-1 WHERE acct_id=1; -- 等A
--                  => InnoDB 检测到死锁，主动回滚代价较小的事务并报错 1213
-- ---------------------------------------------------------------------
-- 避免死锁经验：固定操作表/行的顺序、缩短事务、降低隔离级别、建好索引

-- 查看锁等待情况（诊断常用）
-- SELECT * FROM information_schema.INNODB_TRX;             -- 当前事务
-- SELECT * FROM performance_schema.data_locks;             -- [8.0+] 锁信息
-- SHOW ENGINE INNODB STATUS\G                              -- 最近死锁详情

-- 清理
DROP TABLE IF EXISTS account;

-- =====================================================================
-- 练习
-- 1. 用两个会话验证 RR 下"可重复读"，再改成 RC 验证差异
-- 2. 用 FOR SHARE / FOR UPDATE 区分共享锁与排他锁的兼容性
-- 3. 手工构造一次死锁，并在 SHOW ENGINE INNODB STATUS 中找到死锁日志
-- =====================================================================
