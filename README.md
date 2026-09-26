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
│   │   ├── 05-transaction.sql     # 事务/隔离级别/锁
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
