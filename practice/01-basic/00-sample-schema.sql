-- =====================================================================
-- 章节1 示例库表
-- 用法：docker exec -i mysql-learn-84 mysql -uroot -proot123 < 00-sample-schema.sql
-- 兼容性：MySQL 5.7 / 8.x / 26.x
-- =====================================================================

DROP DATABASE IF EXISTS mysql_learn;
CREATE DATABASE mysql_learn DEFAULT CHARACTER SET utf8mb4;
USE mysql_learn;

-- ---------------------------------------------------------------------
-- 部门表
-- ---------------------------------------------------------------------
CREATE TABLE department (
    dept_id    INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '部门ID',
    dept_name  VARCHAR(50)  NOT NULL COMMENT '部门名称',
    location   VARCHAR(100) DEFAULT NULL COMMENT '办公地点',
    PRIMARY KEY (dept_id),
    UNIQUE KEY uk_dept_name (dept_name)
) COMMENT = '部门表';

-- ---------------------------------------------------------------------
-- 员工表（含主键/唯一/外键/默认值/非空等约束）
-- ---------------------------------------------------------------------
CREATE TABLE employee (
    emp_id      INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '员工ID',
    emp_name    VARCHAR(50)  NOT NULL COMMENT '姓名',
    gender      ENUM('M','F') NOT NULL DEFAULT 'M' COMMENT '性别',
    email       VARCHAR(100) DEFAULT NULL COMMENT '邮箱',
    phone       CHAR(11)     DEFAULT NULL COMMENT '手机号',
    salary      DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '月薪',
    hire_date   DATE         NOT NULL COMMENT '入职日期',
    dept_id     INT UNSIGNED DEFAULT NULL COMMENT '所属部门',
    manager_id  INT UNSIGNED DEFAULT NULL COMMENT '直属上级',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (emp_id),
    UNIQUE KEY uk_email (email),
    KEY idx_dept (dept_id),
    KEY idx_name_salary (emp_name, salary),
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id) REFERENCES department (dept_id),
    CONSTRAINT fk_emp_mgr  FOREIGN KEY (manager_id) REFERENCES employee (emp_id)
) COMMENT = '员工表';

-- ---------------------------------------------------------------------
-- 薪资等级表
-- ---------------------------------------------------------------------
CREATE TABLE salary_grade (
    grade      TINYINT UNSIGNED NOT NULL COMMENT '等级',
    low_salary DECIMAL(10,2) NOT NULL COMMENT '薪资下限',
    high_salary DECIMAL(10,2) NOT NULL COMMENT '薪资上限',
    PRIMARY KEY (grade)
) COMMENT = '薪资等级表';

-- ---------------------------------------------------------------------
-- 初始化数据
-- ---------------------------------------------------------------------
INSERT INTO department (dept_name, location) VALUES
    ('研发部', '北京'),
    ('产品部', '北京'),
    ('市场部', '上海'),
    ('财务部', '深圳'),
    ('行政部', '广州');

-- 先插入没有上级的管理层
INSERT INTO employee (emp_name, gender, email, phone, salary, hire_date, dept_id, manager_id) VALUES
    ('张伟', 'M', 'zhangwei@example.com',  '13800000001', 50000.00, '2015-03-01', 1, NULL),
    ('王芳', 'F', 'wangfang@example.com',  '13800000002', 45000.00, '2016-06-15', 2, NULL),
    ('李娜', 'F', 'lina@example.com',      '13800000003', 40000.00, '2017-02-10', 3, NULL);

-- 再插入普通员工
INSERT INTO employee (emp_name, gender, email, phone, salary, hire_date, dept_id, manager_id) VALUES
    ('刘强', 'M', 'liuqiang@example.com',  '13800000004', 25000.00, '2018-07-01', 1, 1),
    ('陈静', 'F', 'chenjing@example.com',  '13800000005', 22000.00, '2019-04-20', 1, 1),
    ('杨洋', 'M', 'yangyang@example.com',  '13800000006', 18000.00, '2020-09-01', 1, 4),
    ('赵敏', 'F', 'zhaomin@example.com',   '13800000007', 20000.00, '2019-11-11', 2, 2),
    ('孙磊', 'M', 'sunlei@example.com',    '13800000008', 16000.00, '2021-03-15', 2, 2),
    ('周杰', 'M', 'zhoujie@example.com',   '13800000009', 15000.00, '2021-08-08', 3, 3),
    ('吴婷', 'F', 'wuting@example.com',    '13800000010', 13000.00, '2022-05-20', 3, 3),
    ('郑爽', 'F', 'zhengshuang@example.com','13800000011', 12000.00, '2022-10-01', 4, NULL),
    ('冯远', 'M', 'fengyuan@example.com',  '13800000012', 9000.00,  '2023-07-01', 5, NULL),
    ('许晴', 'F', 'xuqing@example.com',    '13800000013', 8500.00,  '2024-02-14', 5, NULL),
    ('马超', 'M', 'machao@example.com',    '13800000014', 30000.00, '2018-01-20', 1, 1),
    ('朱琳', 'F', 'zhulin@example.com',    '13800000015', 7000.00,  '2025-06-01', NULL, NULL);

INSERT INTO salary_grade (grade, low_salary, high_salary) VALUES
    (1,     0.00,  9999.99),
    (2, 10000.00, 19999.99),
    (3, 20000.00, 39999.99),
    (4, 40000.00, 99999.99);

-- 验证
SELECT 'department' AS tbl, COUNT(*) AS cnt FROM department
UNION ALL
SELECT 'employee', COUNT(*) FROM employee
UNION ALL
SELECT 'salary_grade', COUNT(*) FROM salary_grade;
