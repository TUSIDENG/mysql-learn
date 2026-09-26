-- =====================================================================
-- 06-dcl.sql —— DCL 数据控制语言：用户管理、权限授予与回收、角色
-- 需要以 root 执行；以下用户仅为本地学习演示，练完可执行末尾清理
-- =====================================================================

-- =====================================================================
-- 一、查看用户
-- =====================================================================
-- MySQL 8.0：用户与权限统一存在 mysql 系统库的数据字典中
SELECT user, host FROM mysql.user ORDER BY user;

-- 查看当前用户的权限
SHOW GRANTS;
SHOW GRANTS FOR CURRENT_USER;

-- =====================================================================
-- 二、创建/修改/删除用户
-- =====================================================================

-- 创建用户，'user'@'host' 是完整身份；host 限制从哪里能连
-- % 表示任意主机；localhost 仅本机
CREATE USER IF NOT EXISTS 'learner'@'%'
    IDENTIFIED BY 'Learner@123';

-- MySQL 8.0 默认认证插件为 caching_sha2_password（更安全）
-- 若老客户端（或 5.7 应用驱动）连不上，可改为传统插件 mysql_native_password：
--   5.7/8.0：插件默认加载，直接执行 ALTER USER ... WITH mysql_native_password
--   8.4：插件默认禁用，需先在 [mysqld] 配置 mysql_native_password=ON 并重启
--   9.x：插件已彻底移除，无法使用，必须升级客户端/驱动
-- 启用后执行（以下命令在默认配置的 8.4/9.x 上会报 ERROR 1524，故注释）：
-- ALTER USER 'learner'@'%'
--     IDENTIFIED WITH mysql_native_password BY 'Learner@123';

-- 查看当前认证插件状态
SELECT plugin_name, load_option
FROM information_schema.plugins
WHERE plugin_name IN ('caching_sha2_password', 'mysql_native_password');

-- 改密码
ALTER USER 'learner'@'%' IDENTIFIED BY 'NewPass@123';

-- 锁定/解锁账户 [8.0+]
ALTER USER 'learner'@'%' ACCOUNT LOCK;
ALTER USER 'learner'@'%' ACCOUNT UNLOCK;

-- 设置密码过期 [8.0+]
-- ALTER USER 'learner'@'%' PASSWORD EXPIRE;

-- 删除用户（连同权限一起删除；不要直接 DELETE mysql.user）
DROP USER IF EXISTS 'learner'@'%';

-- =====================================================================
-- 三、授权 GRANT
-- =====================================================================
CREATE USER IF NOT EXISTS 'learner'@'%' IDENTIFIED BY 'Learner@123';

-- 授予 mysql_learn 库的查询权限
GRANT SELECT ON mysql_learn.* TO 'learner'@'%';

-- 授予多张表/多种权限
GRANT SELECT, INSERT, UPDATE ON mysql_learn.employee TO 'learner'@'%';

-- 精确到列级权限（一般少用，维护成本高）
GRANT SELECT (emp_id, emp_name), UPDATE (salary)
    ON mysql_learn.employee TO 'learner'@'%';

-- 全部库全部权限（相当于管理员，谨慎授予；学习库 root 之外不要给）
-- GRANT ALL PRIVILEGES ON *.* TO 'learner'@'%';

-- 常用权限：SELECT/INSERT/UPDATE/DELETE/CREATE/ALTER/DROP/INDEX/
--           CREATE VIEW/SHOW VIEW/TRIGGER/CREATE ROUTINE/EXECUTE/
--           REPLICATION CLIENT/REPLICATION SLAVE/GRANT OPTION

-- WITH GRANT OPTION：允许该用户把自己的权限再授予别人
GRANT SELECT ON mysql_learn.* TO 'learner'@'%' WITH GRANT OPTION;

-- 查看授权结果
SHOW GRANTS FOR 'learner'@'%';

-- 5.7 时代修改权限后常需执行 FLUSH PRIVILEGES；
-- 使用 GRANT/CREATE USER 等正规语句则不需要 FLUSH（直接 DELETE 系统表才需要）

-- =====================================================================
-- 四、回收权限 REVOKE
-- =====================================================================
REVOKE INSERT, UPDATE ON mysql_learn.employee FROM 'learner'@'%';
REVOKE GRANT OPTION ON mysql_learn.* FROM 'learner'@'%';

-- 回收全部权限（语法 [8.0 支持，5.7 写法略有差异]）
-- REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'learner'@'%';

SHOW GRANTS FOR 'learner'@'%';

-- =====================================================================
-- 五、角色 ROLE [8.0+，5.7 不支持角色]
-- =====================================================================
-- 角色 = 一组权限的集合，方便批量管理

-- 1) 创建角色
CREATE ROLE IF NOT EXISTS 'app_read', 'app_write';

-- 2) 给角色授权（和给用户授权语法一样）
GRANT SELECT ON mysql_learn.* TO 'app_read';
GRANT INSERT, UPDATE, DELETE ON mysql_learn.* TO 'app_write';

-- 3) 把角色授予用户
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY 'App@123';
GRANT 'app_read' TO 'appuser'@'%';
GRANT 'app_read', 'app_write' TO 'appuser'@'%';

-- 4) 设置登录后默认激活的角色（否则连上后默认没有角色权限）
SET DEFAULT ROLE ALL TO 'appuser'@'%';

-- 查看用户拥有的角色
SELECT CURRENT_ROLE();

-- 5) 撤销角色 / 删除角色
REVOKE 'app_write' FROM 'appuser'@'%';
DROP ROLE IF EXISTS 'app_read', 'app_write';
DROP USER IF EXISTS 'appuser'@'%';

-- =====================================================================
-- 六、最小权限原则（安全实践）
-- =====================================================================
-- 1. 应用账号只给业务库所需权限，不使用 root
-- 2. 限制 host，不用业务账号远程 % 登录管理端
-- 3. 不授 WITH GRANT OPTION / ALL ON *.*
-- 4. 读账号与写账号分离，报表账号只读
-- 5. 定期检查 SHOW GRANTS，清理离职/废弃账号

-- =====================================================================
-- 七、清理本章演示账号
-- =====================================================================
DROP USER IF EXISTS 'learner'@'%';
DROP ROLE IF EXISTS 'app_read', 'app_write';
DROP USER IF EXISTS 'appuser'@'%';
SELECT user, host FROM mysql.user WHERE user IN ('learner', 'appuser');

-- =====================================================================
-- 练习
-- 1. 创建只读账号 ro_user（只能 SELECT mysql_learn），并用该账号登录验证
--    执行 UPDATE 应被拒绝
-- 2. 创建 rw_user，授予 employee 表增删改查，验证不能访问 department
-- 3. [8.0+] 用角色实现：给两个新用户同时授予只读权限
-- 4. 用新账号连接后执行 SELECT @@default_authentication_plugin 对比认证插件
-- =====================================================================
