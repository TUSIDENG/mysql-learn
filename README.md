# mysql学习

此项目涉及mysql基础语法、数据库设计、优化等。还有实际应用实践。

通过 Docker 部署 MySQL，可同时演练以下四个主要版本（含存量巨大的 5.7）：

| 版本 | 类型 | 容器名 | 宿主机端口 | 说明 |
| --- | --- | --- | --- | --- |
| 5.7 | Legacy（2023-10 EOL） | mysql-learn-57 | 3357 | 存量大，用于兼容旧系统与迁移演练 |
| 8.4 | LTS | mysql-learn-84 | 3384 | 长期支持版本，生产常用 |
| 9.7 | LTS | mysql-learn-97 | 3397 | 最后一个传统序号模型的 LTS |
| 26.7 | Innovation | mysql-learn-267 | 33267 | 2026-07 起改用日历版本号(YY.M)，特性最新 |

> root 密码统一为 `root123`（仅用于本地学习）。
> 国内拉取镜像慢时，可将 image 换为 Oracle 仓库：`container-registry.oracle.com/mysql/community-server:<tag>`。
> 5.7 排序规则为 `utf8mb4_unicode_ci`（8.0+ 才有 `utf8mb4_0900_ai_ci`）。

## MySQL 5.7 存量预估

社区支持已于 2023-10-31 终止（末版 5.7.44），但存量依然庞大，不同口径的数据：

| 数据来源（时间） | 口径 | 5.7 占比 |
| --- | --- | --- |
| Percona PMM（2025-11） | 全球 MySQL/MariaDB 实例 | **约 18.8%** |
| WordPress 官方统计（2025-09） | WordPress 站点数据库 | **16.0%**（同年 5 月为 17.8%，缓降中） |
| 阿里云 RDS（2024-01） | 阿里云 RDS for MySQL 用户 | **约 46%** 以 5.7 为主力版本 |

**综合预估**：

- 全球范围：当前 5.7 约占 MySQL 在役实例的 **15%~20%**，仅次于 8.0（约 58%，8.0 已于 2026-04 EOL），呈缓慢下降趋势。
- 国内：因长尾业务、政企/传统行业升级保守，存量比例明显更高，估计在 **25%~35%**；云厂商托管口径中一度接近一半。
- 按趋势，随着 8.0/8.4 迁移推进，预计未来 2~3 年 5.7 会降至 10% 以下，但长期以"难迁移的遗留系统"形式存在。

> 注意：5.7 已无官方安全补丁（Percona 等第三方扩展支持亦有限），新系统不应使用，演练目的仅限兼容与迁移。

## 快速开始

```bash
# 启动指定版本（以 8.4 为例）
cd docker/mysql-8.4
docker compose up -d

# 连接
docker exec -it mysql-learn-84 mysql -uroot -proot123
# 或使用客户端连接 127.0.0.1:3384

# 查看版本
mysql> SELECT VERSION();

# 停止
docker compose down
# 停止并删除数据（重新初始化，PowerShell）
docker compose down; Remove-Item -Recurse -Force data
```

四个版本端口互不冲突，可以同时启动进行特性对比。`initdb/` 中的脚本仅在数据目录首次初始化时自动执行。

### 执行章节1脚本

脚本位于 [practice/01-basic](file:///d:/code/mysql-learn/practice/01-basic)，按编号顺序执行（先跑 `00-sample-schema.sql` 建示例库）：

```powershell
# Windows PowerShell：先设置 UTF-8，避免中文注释被按 ASCII 编码传给 mysql
$OutputEncoding = [System.Text.Encoding]::UTF8

Get-ChildItem practice\01-basic\*.sql | Sort-Object Name | ForEach-Object {
    Write-Host "===== $($_.Name) ====="
    Get-Content $_.FullName -Raw -Encoding UTF8 |
        docker exec -i mysql-learn-84 mysql -uroot -proot123 --default-character-set=utf8mb4
}
```

也可进入容器后用 `source` 执行（需先把脚本拷入容器）：

```bash
docker cp practice/01-basic mysql-learn-84:/sql
docker exec -it mysql-learn-84 mysql -uroot -proot123 \
    -e "SOURCE /sql/00-sample-schema.sql"
```

> 兼容性说明：脚本通用 5.7 ~ 26.x；标注 `[8.0+]` 的窗口函数、CTE、角色等语法在 5.7 上需跳过。

### PowerShell 经 Docker 操作中文乱码（`?` / `??`）

**现象**：`SELECT` 出的中文显示成 `?`，或 `INSERT` 中文后再查变成 `?`（本仓库预览里 `owner` 列的 `??` 就是这个问题）。

**根本原因（两层，缺一不可）**：

1. **容器内 mysql 客户端默认字符集是 `latin1`**（实测 `@@character_set_client/connection/results` 均为 `latin1`）。latin1 无法表示中文，服务端返回的 UTF-8 中文在客户端侧被替换成 `?`；这是 `SELECT` 出现 `?` 的直接原因。
2. **PowerShell 发给原生程序（docker）的字节编码**默认可能不是 UTF-8：Windows PowerShell 5.1 走系统 ANSI 代码页（中文系统为 GBK）。`INSERT` 时若字节编码与客户端声明的字符集不一致，写入的就是错数据。

> 关键认知：`--default-character-set=utf8mb4` 解决第 1 层（客户端与服务端的约定）；PowerShell 编码设置解决第 2 层（本机送出的字节）。**两层都对齐才不乱码。**

#### 第 1 步：连接时始终带 `--default-character-set=utf8mb4`

```powershell
# SELECT：不带该参数是 latin1 → 中文变 ?；带上即正常
docker exec mysql-learn-84 mysql -uroot -proot123 --default-character-set=utf8mb4 `
    -e "SELECT acct_id, owner FROM mysql_learn.account"
```

#### 第 2 步：把 PowerShell 的输出编码设为 UTF-8 再传中文

```powershell
# Windows PowerShell 5.1 必须；PowerShell 7+ 默认即 UTF-8，可跳过
$OutputEncoding = [System.Text.Encoding]::UTF8   # 控制管道给 docker 的字节编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8  # 控制回显，防止结果再被转码
```

#### 场景 A：管道执行 SQL 字符串（INSERT 中文）

```powershell
$OutputEncoding = [System.Text.Encoding]::UTF8
"USE mysql_learn; INSERT INTO account VALUES (3,'张三',100);" |
    docker exec -i mysql-learn-84 mysql -uroot -proot123 --default-character-set=utf8mb4
```

#### 场景 B：管道执行 `.sql` 文件（最常用，注意文件须存为 UTF-8）

```powershell
$OutputEncoding = [System.Text.Encoding]::UTF8
Get-Content practice\01-basic\05-transaction.sql -Raw -Encoding UTF8 |
    docker exec -i mysql-learn-84 mysql -uroot -proot123 --default-character-set=utf8mb4
```

> `-Encoding UTF8` 指定**读取**文件的解码方式（脚本均为 UTF-8 保存）；`$OutputEncoding` 指定**送出**给 docker 的字节编码。两者不是一回事，都要对。
> Windows PowerShell 5.1 的 `Out-File -Encoding UTF8` 会写 **UTF-8 BOM**，自建文件时建议用无 BOM UTF-8（或直接用现有脚本），避免 BOM 被当成 SQL 字符报语法错。

#### 场景 C：`docker exec -it` 交互式会话

```powershell
docker exec -it mysql-learn-84 mysql -uroot -proot123 --default-character-set=utf8mb4
```

进去后可确认三个字符集变量均为 `utf8mb4`：

```sql
SHOW VARIABLES LIKE 'character_set%';
-- 期望 client / connection / results 都是 utf8mb4
```

#### 一劳永逸（可选）

- **用 PowerShell 7（`pwsh`）替代 5.1**：默认 `$OutputEncoding` 与控制台编码均为 UTF-8，只需连接时带 `--default-character-set=utf8mb4`。
- **在容器配置里固化默认字符集**：在 `docker/mysql-8.4/conf/my.cnf` 的 `[client]` 段加 `default-character-set=utf8mb4`（仅影响客户端默认值；服务端字符集在 `[mysqld]` 用 `character-set-server=utf8mb4`），改后需重建容器。

> 排查口诀：存进去用 `HEX(列)` 看字节对不对（区分是"存错了"还是"显示错了"）；中文 UTF-8 每个汉字 3 字节，如"张三"=`E5BCA0 E4B889`。若 HEX 已错，是写入层（第 2 步）问题；HEX 对但显示 `?`，是客户端字符集（第 1 步）问题。

## 项目结构

```
mysql-learn/
├── docker/                        # Docker 部署
│   ├── mysql-5.7/                 # MySQL 5.7（EOL，存量兼容演练）
│   ├── mysql-8.4/                 # MySQL 8.4 LTS
│   │   ├── docker-compose.yml
│   │   ├── conf/my.cnf
│   │   ├── initdb/                # 首次启动初始化脚本
│   │   └── data/                  # 数据持久化（git 忽略）
│   ├── mysql-9.7/                 # MySQL 9.7 LTS（结构同上）
│   └── mysql-26.7/                # MySQL 26.7 Innovation（结构同上）
├── practice/                      # 学习练习
│   ├── 01-basic/                  # 基础语法
│   │   ├── 00-sample-schema.sql   # 示例库表（先执行）
│   │   ├── 01-ddl.sql             # DDL：库/表/约束/索引
│   │   ├── 02-dml.sql             # DML：增删改
│   │   ├── 03-dql.sql             # DQL：查询/连接/子查询/窗口函数
│   │   ├── 04-functions.sql       # 内置函数
│   │   ├── 05-transaction.sql     # 事务/隔离级别/锁（单会话可执行）
│   │   ├── 05-transaction.md      # 配套详解：死锁、锁超时的产生/影响/避免
│   │   ├── 05a-demo-session-a.sql # 双会话并发演示·会话A（与05b同时跑）
│   │   ├── 05b-demo-session-b.sql # 双会话并发演示·会话B（自动复现1205/1213）
│   │   └── 06-dcl.sql             # 用户与权限
│   ├── 02-design/                 # 数据库设计：范式、建模、索引设计
│   ├── 03-optimization/           # 性能优化：EXPLAIN、慢查询、参数调优
│   └── 04-version-drills/         # 5.7/8.4/9.7/26.7 版本差异与新特性演练
├── .gitignore
└── README.md
```

## 前置要求

- Docker Engine 20.10+ / Docker Desktop
- Docker Compose v2（`docker compose` 命令）

## 参考资料

- [小林 coding - 图解 MySQL](https://xiaolincoding.com/mysql/)：图文并茂讲解 MySQL 索引、事务、锁、日志与高可用等核心知识
