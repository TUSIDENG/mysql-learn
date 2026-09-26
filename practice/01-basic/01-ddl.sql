-- =====================================================================
-- 01-ddl.sql —— DDL 数据定义语言：库 / 表 / 列 / 约束 / 索引
-- 建议在 mysql 客户端中逐段执行，观察结果
-- =====================================================================
USE mysql_learn;

-- =====================================================================
-- 一、数据库操作
-- =====================================================================

-- 查看所有数据库
SHOW DATABASES;

-- 创建数据库（指定字符集与排序规则）
CREATE DATABASE IF NOT EXISTS ddl_demo
    DEFAULT CHARACTER SET utf8mb4;

-- 修改数据库字符集
ALTER DATABASE ddl_demo DEFAULT CHARACTER SET utf8mb4;

-- 查看建库语句
SHOW CREATE DATABASE ddl_demo;

-- 删除数据库（危险！确认后再执行）
-- DROP DATABASE ddl_demo;

USE ddl_demo;

-- =====================================================================
-- 二、常用数据类型
-- =====================================================================
-- 整数：TINYINT / SMALLINT / MEDIUMINT / INT / BIGINT（UNSIGNED 可将负数范围让给正数）
-- 小数：DECIMAL(M,D) 精确（金额用）；FLOAT/DOUBLE 浮点（有精度损失）
-- 字符串：CHAR(定长) / VARCHAR(变长) / TEXT 系列 / ENUM / SET
-- 日期：DATE / TIME / DATETIME / TIMESTAMP / YEAR
-- JSON：MySQL 5.7.8+ 支持

-- =====================================================================
-- 三、建表与约束
-- =====================================================================
DROP TABLE IF EXISTS t_user;
CREATE TABLE t_user (
    user_id    INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    username   VARCHAR(50)  NOT NULL COMMENT '用户名',
    age        TINYINT UNSIGNED DEFAULT NULL COMMENT '年龄',
    balance    DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '余额',
    status     TINYINT      NOT NULL DEFAULT 1 COMMENT '状态 1正常 0禁用',
    profile    JSON         DEFAULT NULL COMMENT '资料(JSON, 5.7.8+)',
    create_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                          ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间', -- 5.7+ 支持
    -- 主键约束
    PRIMARY KEY (user_id),
    -- 唯一约束
    UNIQUE KEY uk_username (username),
    -- 检查约束：8.0.16+ 真正强制执行；5.7 仅语法解析不生效
    CONSTRAINT chk_age CHECK (age BETWEEN 0 AND 150)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '用户演示表';

-- 查看表结构与建表语句
DESC t_user;
SHOW CREATE TABLE t_user\G

-- =====================================================================
-- 四、外键约束演示
-- =====================================================================
DROP TABLE IF EXISTS t_order;
CREATE TABLE t_order (
    order_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id    INT UNSIGNED NOT NULL,
    amount     DECIMAL(10,2) NOT NULL,
    order_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id),
    KEY idx_user (user_id),
    -- 外键：限制从表不能引用主表不存在的值
    CONSTRAINT fk_order_user FOREIGN KEY (user_id)
        REFERENCES t_user (user_id)
        ON UPDATE CASCADE   -- 主表主键变更时级联更新
        ON DELETE RESTRICT  -- 主表记录被引用时禁止删除
);

-- =====================================================================
-- 五、ALTER 修改表结构
-- =====================================================================

-- 1) 增加列
ALTER TABLE t_user ADD COLUMN nickname VARCHAR(50) DEFAULT NULL AFTER username;
ALTER TABLE t_user ADD COLUMN (
    city VARCHAR(50) DEFAULT NULL,
    zip  CHAR(6)     DEFAULT NULL
);

-- 2) 修改列定义（MODIFY 只改类型/属性，不能改名）
ALTER TABLE t_user MODIFY COLUMN status TINYINT NOT NULL DEFAULT 1 COMMENT '1正常 0禁用 2注销';

-- 3) CHANGE 可同时改列名和定义
ALTER TABLE t_user CHANGE COLUMN nickname nick VARCHAR(50) DEFAULT NULL;

-- 4) 删除列
ALTER TABLE t_user DROP COLUMN zip;

-- 5) 重命名表
RENAME TABLE t_user TO t_account;
ALTER TABLE t_account RENAME TO t_user;

-- =====================================================================
-- 六、索引操作
-- =====================================================================

-- 创建索引
CREATE INDEX idx_city ON t_user (city);
CREATE UNIQUE INDEX uk_nick ON t_user (nick);

-- 组合索引（最左前缀原则在 03-dql.sql / 03-optimization 中演练）
CREATE INDEX idx_status_city ON t_user (status, city);

-- 查看索引
SHOW INDEX FROM t_user;

-- 删除索引
DROP INDEX uk_nick ON t_user;
ALTER TABLE t_user DROP INDEX idx_city;

-- =====================================================================
-- 七、清空与删除
-- =====================================================================
-- DELETE：DML，逐行删除，可带 WHERE，可回滚，不清 AUTO_INCREMENT
-- TRUNCATE：DDL，清空整表并重置 AUTO_INCREMENT，不可回滚，速度快
-- DROP：DDL，删除表结构本身

-- TRUNCATE TABLE t_order;
-- DROP TABLE t_order, t_user;

-- 清理演示库
DROP DATABASE IF EXISTS ddl_demo;

-- =====================================================================
-- 练习
-- 1. 在 mysql_learn 中新建 project 表：项目ID(主键)、项目名(唯一非空)、
--    负责人(外键 -> employee.emp_id)、预算 DECIMAL(12,2)、开始日期
-- 2. 给 project 表增加 end_date 列，再为 (负责人, 开始日期) 建组合索引
-- 3. 查看 employee 表的全部索引并说明每个索引的作用
-- =====================================================================
