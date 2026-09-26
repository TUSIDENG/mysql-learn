-- =====================================================================
-- 02-dml.sql —— DML 数据操作语言：INSERT / UPDATE / DELETE / REPLACE
-- 为不破坏 00 脚本中的演示数据，本章在 employee_bak 副本上操作
-- =====================================================================
USE mysql_learn;

DROP TABLE IF EXISTS employee_bak;
CREATE TABLE employee_bak AS
SELECT emp_id, emp_name, gender, salary, dept_id, hire_date
FROM employee;
SELECT COUNT(*) AS bak_rows FROM employee_bak;

-- =====================================================================
-- 一、INSERT
-- =====================================================================

-- 1) 单行插入（指定列）
INSERT INTO employee_bak (emp_name, gender, salary, dept_id, hire_date)
VALUES ('测试甲', 'M', 10000.00, 1, '2026-01-01');

-- 2) 批量插入（比循环单条快得多）
INSERT INTO employee_bak (emp_name, gender, salary, dept_id, hire_date) VALUES
    ('测试乙', 'F', 11000.00, 1, '2026-02-01'),
    ('测试丙', 'M', 12000.00, 2, '2026-03-01');

-- 3) 全列插入（必须按表结构列顺序，不推荐）
-- INSERT INTO employee_bak VALUES (100, '测试丁', 'M', 9000, 3, '2026-04-01');

-- 4) INSERT ... SET（可读性好，MySQL 扩展语法）
INSERT INTO employee_bak SET emp_name = '测试戊', gender = 'F', salary = 9500, hire_date = '2026-05-01';

-- 5) 插入查询结果（列顺序/类型要对应）
INSERT INTO employee_bak (emp_name, gender, salary, dept_id, hire_date)
SELECT emp_name, gender, salary, dept_id, hire_date
FROM employee
WHERE salary < 10000;

-- 6) 处理唯一键冲突
--    INSERT IGNORE：冲突时跳过并产生警告
--    ON DUPLICATE KEY UPDATE：冲突时改为更新（MySQL 特有，非常常用）
CREATE TEMPORARY TABLE tmp_upsert (
    id INT PRIMARY KEY,
    name VARCHAR(20),
    cnt INT
);
INSERT INTO tmp_upsert (id, name, cnt) VALUES (1, 'A', 1)
ON DUPLICATE KEY UPDATE cnt = cnt + 1;
-- 再执行一次（可手工重复运行），cnt 会变成 2
INSERT INTO tmp_upsert (id, name, cnt) VALUES (1, 'A', 1)
ON DUPLICATE KEY UPDATE cnt = cnt + 1;
SELECT * FROM tmp_upsert;

-- =====================================================================
-- 二、UPDATE
-- =====================================================================

-- 1) 带条件更新（务必写 WHERE！）
UPDATE employee_bak
SET salary = salary + 500
WHERE emp_name = '测试甲';

-- 2) 多列更新
UPDATE employee_bak
SET salary = salary * 1.1,
    dept_id = 2
WHERE dept_id = 3;

-- 3) 表关联更新（把研发部员工薪资按部门表 location 信息更新是常见场景）
-- 用 employee + department 的关联写法：
UPDATE employee e
JOIN department d ON e.dept_id = d.dept_id
SET e.salary = e.salary  -- 仅演示语法，这里不实际改动
WHERE d.location = '北京';

-- 4) ORDER BY + LIMIT 更新部分行
UPDATE employee_bak
SET salary = salary + 100
ORDER BY salary ASC
LIMIT 3;

-- =====================================================================
-- 三、DELETE
-- =====================================================================

-- 1) 条件删除
DELETE FROM employee_bak
WHERE emp_name LIKE '测试%';

-- 2) 关联删除：删除“无部门员工”的副本行
DELETE b
FROM employee_bak b
LEFT JOIN department d ON b.dept_id = d.dept_id
WHERE d.dept_id IS NULL;

-- 3) LIMIT 删除
DELETE FROM employee_bak
ORDER BY hire_date DESC
LIMIT 2;

-- 4) 清空（DML，可回滚但不带 WHERE；AUTO_INCREMENT 不重置）
-- DELETE FROM employee_bak;
-- 对比 DDL：TRUNCATE 更快、重置自增、不可回滚

SELECT COUNT(*) AS remaining FROM employee_bak;

-- =====================================================================
-- 四、REPLACE INTO
-- =====================================================================
-- 无冲突时等同 INSERT；主键/唯一键冲突时先 DELETE 旧行再 INSERT
-- 注意：会触发两次动作，外键场景慎用；自增ID会变
REPLACE INTO tmp_upsert (id, name, cnt) VALUES (1, 'A-replaced', 0);
SELECT * FROM tmp_upsert;

-- 清理
DROP TABLE IF EXISTS employee_bak;

-- =====================================================================
-- 练习
-- 1. 用 INSERT ... SELECT 把 employee 中研发部的人复制到一张新表 emp_rd
-- 2. 用一条 UPDATE 给“薪资低于部门平均薪资”的员工普调 3%（提示 JOIN 子查询）
-- 3. 用 ON DUPLICATE KEY UPDATE 实现：统计表各部门人数，重复执行结果仍正确
-- =====================================================================
