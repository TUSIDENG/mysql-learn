-- =====================================================================
-- 03-dql.sql —— DQL 数据查询语言（本章重点）
-- 基础/分组/多表连接/子查询/集合运算/CASE/窗口函数/CTE
-- 标注 [8.0+] 的语法在 MySQL 5.7 不可用
-- =====================================================================
USE mysql_learn;

-- =====================================================================
-- 一、基础查询
-- =====================================================================

-- 查询全部列（生产环境避免 SELECT *，明确列名）
SELECT * FROM employee;

-- 指定列 + 别名（AS 可省略；含空格的别名要加引号）
SELECT emp_id AS id, emp_name AS emp_name_cn, salary * 12 AS annual_salary
FROM employee;
-- 若需要中文列名，用反引号包裹：emp_name AS `姓名`（含中文的脚本注意客户端字符集）

-- DISTINCT 去重
SELECT DISTINCT dept_id FROM employee;
SELECT DISTINCT gender, dept_id FROM employee;  -- 多列组合去重

-- =====================================================================
-- 二、WHERE 条件过滤
-- =====================================================================
SELECT emp_name, salary
FROM employee
WHERE salary >= 20000;

-- 比较运算：= <> != > < >= <=
-- 逻辑运算：AND OR NOT
SELECT emp_name, gender, salary
FROM employee
WHERE (gender = 'F' OR salary > 25000)
  AND salary < 50000;

-- BETWEEN ... AND ...（含边界，等价于 >= AND <=）
SELECT emp_name, salary
FROM employee
WHERE salary BETWEEN 10000 AND 20000;

-- IN 列表
SELECT emp_name, dept_id
FROM employee
WHERE dept_id IN (1, 2, 4);

-- IS NULL / IS NOT NULL（NULL 不能用 = NULL 判断）
SELECT emp_name, dept_id
FROM employee
WHERE dept_id IS NULL;

-- LIKE 模糊：% 任意多个字符，_ 单个字符
SELECT emp_name
FROM employee
WHERE emp_name LIKE '张%';     -- 姓张
-- WHERE phone LIKE '138%001';
-- WHERE emp_name LIKE '_芳';  -- 名字两个字，第二个是芳

-- =====================================================================
-- 三、ORDER BY 排序
-- =====================================================================
SELECT emp_name, salary, hire_date
FROM employee
ORDER BY salary DESC, hire_date ASC;  -- 薪资降序，相同则入职早的在前

-- 可按别名、列序号排序（列序号可读性差，不推荐）
SELECT emp_name, salary * 12 AS annual
FROM employee
ORDER BY annual DESC;

-- =====================================================================
-- 四、LIMIT 分页
-- =====================================================================
SELECT emp_name, salary
FROM employee
ORDER BY salary DESC
LIMIT 5;              -- 前 5 名

-- LIMIT offset, row_count：跳过 5 行取 5 行（第 2 页）
SELECT emp_name, salary
FROM employee
ORDER BY salary DESC
LIMIT 5, 5;

-- [8.0.19+] 更清晰的写法
-- SELECT * FROM employee ORDER BY emp_id LIMIT 5 OFFSET 5;

-- 注意：大偏移量分页（LIMIT 1000000,20）性能差，优化章节讲"书签法"

-- =====================================================================
-- 五、聚合函数与分组
-- =====================================================================
-- 聚合：COUNT / SUM / AVG / MAX / MIN
SELECT
    COUNT(*)        AS emp_count,      -- 行数（含 NULL 行概念，通常用 *）
    COUNT(dept_id)  AS dept_not_null,  -- 该列非 NULL 的个数
    SUM(salary)     AS total_salary,
    AVG(salary)     AS avg_salary,
    MAX(salary)     AS max_salary,
    MIN(salary)     AS min_salary
FROM employee;

-- GROUP BY 分组聚合
SELECT dept_id,
       COUNT(*)  AS cnt,
       AVG(salary) AS avg_salary
FROM employee
WHERE dept_id IS NOT NULL
GROUP BY dept_id;

-- 多列分组
SELECT dept_id, gender, COUNT(*) AS cnt
FROM employee
GROUP BY dept_id, gender
ORDER BY dept_id;

-- HAVING：对分组"之后"的结果过滤（WHERE 不能用聚合函数，HAVING 可以）
SELECT dept_id, COUNT(*) AS cnt, AVG(salary) AS avg_sal
FROM employee
GROUP BY dept_id
HAVING COUNT(*) >= 2 AND AVG(salary) > 15000;

-- 执行顺序：FROM -> WHERE -> GROUP BY -> HAVING -> SELECT -> ORDER BY -> LIMIT
-- 注意 ONLY_FULL_GROUP_BY（5.7+ 默认开启）：SELECT 中非聚合列必须出现在 GROUP BY 中

-- WITH ROLLUP：生成汇总行 [5.7 就支持；8.0 语法略增强]
SELECT dept_id, gender, COUNT(*) AS cnt
FROM employee
WHERE dept_id IS NOT NULL
GROUP BY dept_id, gender WITH ROLLUP;

-- =====================================================================
-- 六、多表连接 JOIN
-- =====================================================================

-- 1) INNER JOIN：只返回两表匹配的行（员工 + 部门名）
SELECT e.emp_name, d.dept_name, e.salary
FROM employee e
INNER JOIN department d ON e.dept_id = d.dept_id;

-- 2) LEFT JOIN：左表全保留，右表无匹配补 NULL（查"没有部门的员工"）
SELECT e.emp_name, d.dept_name
FROM employee e
LEFT JOIN department d ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL;

-- 查"没有员工的部门"（左连接反连接经典写法）
SELECT d.dept_name
FROM department d
LEFT JOIN employee e ON d.dept_id = e.dept_id
WHERE e.emp_id IS NULL;

-- 3) RIGHT JOIN：右表全保留（能改写成 LEFT 就尽量用 LEFT，可读性好）
SELECT e.emp_name, d.dept_name
FROM employee e
RIGHT JOIN department d ON e.dept_id = d.dept_id;

-- 4) 三表连接：员工 + 部门 + 薪资等级
SELECT e.emp_name, d.dept_name, e.salary, g.grade
FROM employee e
JOIN department d ON e.dept_id = d.dept_id
JOIN salary_grade g ON e.salary BETWEEN g.low_salary AND g.high_salary
ORDER BY g.grade;

-- 5) 自连接：员工的上级也是员工（manager_id -> emp_id）
SELECT m.emp_name AS manager, s.emp_name AS subordinate
FROM employee s
JOIN employee m ON s.manager_id = m.emp_id
ORDER BY m.emp_name;

-- 6) USING 简写（两表连接列同名时）
-- SELECT emp_name, dept_name FROM employee JOIN department USING (dept_id);

-- 7) CROSS JOIN 笛卡尔积（慎用，m*n 行）
-- SELECT * FROM employee CROSS JOIN department;

-- =====================================================================
-- 七、子查询
-- =====================================================================

-- 1) 标量子查询（返回单值，可放 SELECT/WHERE）
SELECT emp_name, salary,
       (SELECT ROUND(AVG(salary),2) FROM employee) AS company_avg,
       salary - (SELECT AVG(salary) FROM employee) AS diff
FROM employee;

-- 2) IN 子查询：薪资等于某部门最高薪资的人
SELECT emp_name, salary
FROM employee
WHERE salary IN (
    SELECT MAX(salary) FROM employee GROUP BY dept_id
);

-- 3) EXISTS 相关子查询：有员工的部门（EXISTS 找到即停，常比 IN 高效）
SELECT d.dept_id, d.dept_name
FROM department d
WHERE EXISTS (
    SELECT 1 FROM employee e WHERE e.dept_id = d.dept_id
);

-- 4) 派生表（子查询放在 FROM 中，必须有别名）
SELECT dept_id, avg_sal
FROM (
    SELECT dept_id, AVG(salary) AS avg_sal, COUNT(*) AS cnt
    FROM employee
    WHERE dept_id IS NOT NULL
    GROUP BY dept_id
) t
WHERE cnt >= 2
ORDER BY avg_sal DESC;

-- 5) ANY / ALL
SELECT emp_name, salary
FROM employee
WHERE salary > ALL (SELECT salary FROM employee WHERE dept_id = 3); -- 比市场部所有人都高

-- =====================================================================
-- 八、UNION 集合运算
-- =====================================================================
-- UNION 去重；UNION ALL 不去重（更快，确认无重复时优先）
SELECT emp_name, salary, '高薪' AS type FROM employee WHERE salary >= 20000
UNION ALL
SELECT emp_name, salary, '低薪' FROM employee WHERE salary < 10000
ORDER BY salary DESC;
-- 各分支列数、类型要对应；ORDER BY/LIMIT 写在最后

-- =====================================================================
-- 九、CASE 条件表达式
-- =====================================================================
SELECT emp_name, salary,
    CASE
        WHEN salary >= 40000 THEN '高管'
        WHEN salary >= 20000 THEN '骨干'
        WHEN salary >= 10000 THEN '普通'
        ELSE '初级'
    END AS level_name
FROM employee
ORDER BY salary DESC;

-- 简单 CASE（等值匹配）
SELECT emp_name,
    CASE gender WHEN 'M' THEN '男' WHEN 'F' THEN '女' END AS gender_cn
FROM employee;

-- 实战：按等级分别统计人数（行转列思想）
SELECT
    SUM(CASE WHEN salary >= 20000 THEN 1 ELSE 0 END) AS high_cnt,
    SUM(CASE WHEN salary BETWEEN 10000 AND 19999 THEN 1 ELSE 0 END) AS mid_cnt,
    SUM(CASE WHEN salary < 10000 THEN 1 ELSE 0 END) AS low_cnt
FROM employee;

-- =====================================================================
-- 十、窗口函数 [8.0+，5.7 请跳过本节]
-- =====================================================================

-- ROW_NUMBER / RANK / DENSE_RANK 排名
SELECT emp_name, dept_id, salary,
    ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rn,
    RANK()       OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rk,
    DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS drk
FROM employee
WHERE dept_id IS NOT NULL;

-- 与 GROUP BY 不同：窗口函数不折叠行，每行都保留且附带聚合值
SELECT emp_name, dept_id, salary,
    SUM(salary) OVER (PARTITION BY dept_id) AS dept_total,
    AVG(salary) OVER (PARTITION BY dept_id) AS dept_avg
FROM employee;

-- LAG / LEAD 取前后行；计算与上一名的薪资差
SELECT emp_name, salary,
    LAG(salary)  OVER (ORDER BY salary DESC) AS prev_salary,
    salary - LAG(salary) OVER (ORDER BY salary DESC) AS gap
FROM employee;

-- NTILE 分组、FIRST_VALUE/LAST_VALUE 等
SELECT emp_name, salary,
    NTILE(4) OVER (ORDER BY salary DESC) AS quartile
FROM employee;

-- =====================================================================
-- 十一、CTE 公用表表达式 [8.0+，5.7 请改写为派生表]
-- =====================================================================
WITH dept_stat AS (
    SELECT dept_id, AVG(salary) AS avg_sal, COUNT(*) AS cnt
    FROM employee
    WHERE dept_id IS NOT NULL
    GROUP BY dept_id
)
SELECT e.emp_name, e.salary, s.avg_sal
FROM employee e
JOIN dept_stat s ON e.dept_id = s.dept_id
WHERE e.salary > s.avg_sal;

-- =====================================================================
-- 练习
-- 1. 查询各部门薪资最高的员工姓名和薪资（至少用两种写法：子查询 / 窗口函数）
-- 2. 查询入职年份与人数，按人数降序（提示 YEAR(hire_date)）
-- 3. 查询比"本部门平均薪资"高的员工
-- 4. 用自连接找出：每个员工与其上级的薪资差，上级为空的显示"老板"
-- 5. 统计连续两年（任意相邻年份）都有新人入职的部门
-- =====================================================================
