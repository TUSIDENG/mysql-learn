-- =====================================================================
-- 04-functions.sql —— 常用内置函数
-- 字符串 / 数值 / 日期 / 控制流 / JSON / 聚合 / 信息函数
-- =====================================================================
USE mysql_learn;

-- =====================================================================
-- 一、字符串函数
-- =====================================================================
SELECT
    LENGTH('MySQL学习')      AS byte_len,    -- 字节数（utf8mb4 一个汉字3字节）
    CHAR_LENGTH('MySQL学习') AS char_len,    -- 字符数
    CONCAT('My', 'SQL', '-', '8.4') AS concat_str,
    CONCAT_WS('-', '2026', '09', '25') AS concat_ws_str, -- 用分隔符拼接，自动跳过 NULL
    LOWER('MySQL') AS lower_str,
    UPPER('mysql') AS upper_str,
    TRIM('  hi  ') AS trim_str,
    LPAD('7', 3, '0') AS lpad_str,   -- 左填充 -> 007
    REPLACE('a-b-c', '-', '+') AS replaced,
    SUBSTRING('MySQL', 1, 3) AS sub_str,  -- SQL 标准从 1 开始计数
    LEFT('MySQL', 2) AS left_str,
    INSTR('MySQL', 'S') AS pos,
    REVERSE('abc') AS rev;

-- =====================================================================
-- 二、数值函数
-- =====================================================================
SELECT
    ABS(-10)        AS abs_v,
    ROUND(3.567, 2) AS round_v,    -- 3.57
    CEIL(3.1)       AS ceil_v,     -- 4（天花板）
    FLOOR(3.9)      AS floor_v,    -- 3
    TRUNCATE(3.567, 2) AS trunc_v, -- 3.56（直接截断不四舍五入）
    MOD(10, 3)      AS mod_v,      -- 1
    RAND()          AS rand_v,     -- 0~1 随机数
    SIGN(-8)        AS sign_v,     -- -1
    POW(2, 10)      AS pow_v;      -- 1024

-- 应用：随机抽 3 名员工（数据量大时不要对全表 ORDER BY RAND()，优化章节再讲）
SELECT emp_name FROM employee ORDER BY RAND() LIMIT 3;

-- =====================================================================
-- 三、日期时间函数（最常用）
-- =====================================================================
SELECT
    NOW()        AS now_dt,        -- 当前日期时间
    CURDATE()    AS today,         -- 当前日期
    CURTIME()    AS now_time,      -- 当前时间
    YEAR(NOW())  AS y,
    MONTH(NOW()) AS m,
    DAY(NOW())   AS d,
    DAYNAME(NOW()) AS day_name,
    DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s') AS formatted,
    DATEDIFF('2026-12-31', '2026-01-01') AS days_diff,  -- 相隔天数
    TIMESTAMPDIFF(YEAR, '2000-01-01', NOW()) AS age_years,
    DATE_ADD(NOW(), INTERVAL 3 MONTH) AS plus_3m,
    DATE_SUB(NOW(), INTERVAL 7 DAY)  AS minus_7d,
    LAST_DAY(NOW()) AS month_end;

-- 应用：查询工龄
SELECT emp_name,
    hire_date,
    TIMESTAMPDIFF(YEAR, hire_date, CURDATE()) AS work_years
FROM employee
ORDER BY work_years DESC;

-- 应用：按入职年月统计
SELECT DATE_FORMAT(hire_date, '%Y-%m') AS ym, COUNT(*) AS cnt
FROM employee
GROUP BY ym
ORDER BY ym;

-- UNIX 时间戳
SELECT UNIX_TIMESTAMP() AS ts, FROM_UNIXTIME(UNIX_TIMESTAMP()) AS back_dt;

-- =====================================================================
-- 四、控制流与判断函数
-- =====================================================================
SELECT
    IF(1 > 0, 'yes', 'no')                AS if_v,
    IFNULL(NULL, 'default')               AS ifnull_v,  -- NULL 时给默认值（最常用）
    NULLIF('a', 'a')                      AS nullif_v,  -- 相等返回 NULL
    COALESCE(NULL, NULL, 'first', 'x')    AS coalesce_v;-- 返回第一个非 NULL

SELECT emp_name,
    IFNULL(phone, '未登记') AS phone_v
FROM employee;

-- =====================================================================
-- 五、JSON 函数 [5.7.8+]
-- =====================================================================
SELECT
    JSON_OBJECT('name', 'Tom', 'age', 18) AS j_obj,
    JSON_ARRAY(1, 2, 3)                   AS j_arr;

-- 注意：-> / ->> 操作符只能作用于 JSON 列（不能直接作用字符串字面量）
CREATE TEMPORARY TABLE tmp_json_demo (doc JSON);
INSERT INTO tmp_json_demo VALUES ('{"name":"Tom","info":{"age":18}}');

SELECT
    JSON_EXTRACT(doc, '$.name')    AS name_v,        -- 带引号 "Tom"
    JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) AS name_unq, -- 去引号 Tom
    doc->>'$.name'                 AS short_name     -- 等价写法 [5.7.13+]
FROM tmp_json_demo;

-- 对真实表使用 JSON（先给 employee 加个扩展列演示）
ALTER TABLE employee ADD COLUMN ext_info JSON DEFAULT NULL;
UPDATE employee SET ext_info = JSON_OBJECT('skill', 'Java', 'level', 3)
WHERE emp_name = '刘强';

SELECT emp_name, JSON_EXTRACT(ext_info, '$.skill') AS skill
FROM employee
WHERE ext_info IS NOT NULL;

-- JSON 修改函数
SELECT JSON_SET('{"a":1}', '$.a', 10, '$.b', 2)   AS set_v,   -- 有则改无则增
       JSON_INSERT('{"a":1}', '$.a', 10, '$.b', 2) AS ins_v,  -- 只增不改
       JSON_REMOVE('{"a":1,"b":2}', '$.b')         AS rm_v;
ALTER TABLE employee DROP COLUMN ext_info;  -- 还原表结构

-- =====================================================================
-- 六、聚合函数补充
-- =====================================================================
-- COUNT/SUM/AVG/MAX/MIN 见 03-dql.sql
SELECT GROUP_CONCAT(emp_name ORDER BY salary DESC SEPARATOR '、') AS all_names
FROM employee
WHERE dept_id = 1;
-- 注意结果受 group_concat_max_len 限制（默认 1024 字节），超长会被截断

-- =====================================================================
-- 七、系统/信息函数
-- =====================================================================
SELECT VERSION()       AS mysql_version,
       DATABASE()      AS current_db,
       CURRENT_USER()  AS login_user,
       CONNECTION_ID() AS conn_id,
       UUID()          AS uuid_v,
       INET_ATON('192.168.1.1') AS ip_num;

-- =====================================================================
-- 练习
-- 1. 查询每个员工的工龄（满几年）和入职时的星期几（中文）
-- 2. 把手机号中间 4 位替换为 ****（提示 CONCAT + SUBSTRING/REPLACE）
-- 3. 生成"2026-01 至 2026-06"每月最后一天的日期
-- 4. 查询各部门员工姓名，逗号分隔为一行（GROUP_CONCAT）
-- =====================================================================
