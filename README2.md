基于我们刚才实际跑通的 **Windows + GNAT 16.1 + GPRbuild + Firebird 5 + 64-bit ODBC + Ada** 项目。

# Ada + ODBC + Firebird 5 完整教程

## 1. 项目简介

本项目演示如何在 Windows 下使用 Ada 通过 ODBC 连接 Firebird 5 数据库。

技术栈：

| 组件       | 版本/说明                       |
| -------- | --------------------------- |
| 操作系统     | Windows 64-bit              |
| Ada      | GNAT 16.1.0                 |
| 构建工具     | GPRbuild                    |
| 数据库      | Firebird 5                  |
| 数据库接口    | ODBC                        |
| ODBC 驱动  | Firebird ODBC Driver 64-bit |
| 程序       | Ada                         |
| ODBC DLL | `odbc32.dll`                |

程序最终实现：

```text
Ada
 │
 │ ODBC API
 ▼
Windows ODBC Driver Manager
 │
 │
 ▼
Firebird ODBC Driver 64-bit
 │
 ▼
Firebird 5
 │
 ▼
test.fdb
```

---

# 2. 项目目录

项目结构：

```text
ada_odbc_firebird/
│
├── ada_odbc_firebird.gpr
├── main.adb
├── odbc.ads
├── odbc.adb
│
├── obj/
│
└── bin/
    └── main.exe
```

其中：

```text
odbc.ads
```

是 ODBC 接口声明。

```text
odbc.adb
```

是 ODBC Ada 封装实现。

```text
main.adb
```

是测试程序。

```text
ada_odbc_firebird.gpr
```

是 GPRbuild 项目文件。

---

# 3. 环境准备

## 3.1 GNAT

本项目使用：

```text
GNAT 16.1.0
```

可以通过 Alire 安装 GNAT 工具链。

确认：

```nu
gnat --version
```

例如：

```text
GNAT 16.1.0
```

确认 GPRbuild：

```nu
gprbuild --version
```

---

# 4. Firebird 5

假设 Firebird 安装在：

```text
D:\Firebird\Firebird_5_0
```

其中应该包含：

```text
isql.exe
fbclient.dll
```

可以用：

```nu
ls D:\Firebird\Firebird_5_0
```

检查。

---

# 5. 创建 Firebird 数据库

例如数据库：

```text
F:\proj-2025\ada\data\test.fdb
```

可以使用 Firebird `isql.exe` 创建数据库。

例如：

```nu
'D:\Firebird\Firebird_5_0\isql.exe' -user SYSDBA -password 123456
```

然后：

```sql
CREATE DATABASE 'F:\proj-2025\ada\data\test.fdb';
```

退出：

```sql
QUIT;
```

也可以直接使用数据库文件进行后续连接。

---

# 6. Firebird 用户

本项目使用：

```text
Username: SYSDBA
Password: 123456
```

因此 Ada 中的连接字符串使用：

```text
UID=SYSDBA;
PWD=123456;
```

实际项目中不建议把数据库密码硬编码在源码中。

后续可以改成：

```text
环境变量
配置文件
命令行参数
Windows Credential Manager
```

等方式。

---

# 7. 安装 Firebird ODBC Driver

这是本项目非常重要的一部分。

Windows 上存在两个 ODBC Driver Manager：

```text
32-bit
64-bit
```

而我们使用的 GNAT 程序是：

```text
64-bit
```

所以必须使用：

```text
Firebird ODBC Driver 64-bit
```

---

# 8. 检查 ODBC 驱动

Windows PowerShell 的：

```text
Get-OdbcDriver
```

不是 Nushell 命令。

由于本项目使用 Nushell，可以从 Nushell 调用 PowerShell：

```nu
powershell.exe -NoProfile -Command "Get-OdbcDriver | Format-Table Name,Platform,Version"
```

最终我们实际得到：

```text
Firebird ODBC Driver    32-bit
Firebird ODBC Driver    64-bit
```

因此：

```text
64-bit Ada
    ↓
64-bit ODBC Driver Manager
    ↓
Firebird ODBC Driver 64-bit
```

匹配正确。

---

# 9. 最重要的连接字符串问题

一开始使用的是：

```text
DRIVER=Firebird/InterBase(r) driver;
```

导致：

```text
SQLSTATE     : IM002
Native Error : 0
Message      : [Microsoft][ODBC 驱动程序管理器]
               未发现数据源名称并且未指定默认驱动程序
```

原因不是 Ada，也不是 Firebird 数据库。

而是：

```text
DRIVER=
```

后面的名字与 Windows 中实际注册的 ODBC Driver 名称不一致。

实际驱动名称是：

```text
Firebird ODBC Driver
```

因此最终连接字符串必须使用：

```ada
"DRIVER=Firebird ODBC Driver;"
```

这是本项目非常重要的经验。

---

# 10. 最终连接字符串

本项目使用：

```ada
Connection_String : constant String :=
  "DRIVER=Firebird ODBC Driver;"
  & "DBNAME=localhost:F:\proj-2025\ada\data\test.fdb;"
  & "UID=SYSDBA;"
  & "PWD=123456;";
```

各部分含义：

```text
DRIVER=Firebird ODBC Driver;
```

指定 ODBC Driver。

```text
DBNAME=localhost:F:\proj-2025\ada\data\test.fdb;
```

指定 Firebird 数据库。

```text
UID=SYSDBA;
```

用户名。

```text
PWD=123456;
```

密码。

---

# 11. GPR 项目文件

当前项目使用：

```ada
project Ada_Odbc_Firebird is

   for Languages use ("Ada");

   for Main use ("main.adb");

   for Source_Dirs use (".");
   for Object_Dir use "obj";
   for Exec_Dir use "bin";

   package Linker is
      for Default_Switches ("Ada") use ("-lodbc32");
   end Linker;

end Ada_Odbc_Firebird;
```

这里：

```ada
-lodbc32
```

表示链接 Windows ODBC：

```text
odbc32.dll
```

注意，这个是 **Windows ODBC Driver Manager**，不是 Firebird 的 `fbclient.dll`。

整体关系：

```text
main.exe
   │
   ├── odbc32.dll
   │       │
   │       └── Firebird ODBC Driver
   │                    │
   │                    └── Firebird Server
   │
   └── Ada runtime
```

---

# 12. ODBC Ada 类型映射

ODBC 是 C API，所以 Ada 必须正确映射 C 类型。

项目中使用：

```ada
with System;
with Interfaces.C;
```

核心类型：

```ada
subtype SQLSMALLINT  is Interfaces.C.short;
subtype SQLUSMALLINT is Interfaces.C.unsigned_short;
subtype SQLINTEGER   is Interfaces.C.int;
```

Windows 64-bit 下：

```ada
subtype SQLLEN  is Interfaces.C.long_long;
subtype SQLULEN is Interfaces.C.unsigned_long_long;
```

句柄：

```ada
subtype SQLHANDLE is System.Address;

subtype SQLHENV  is SQLHANDLE;
subtype SQLHDBC  is SQLHANDLE;
subtype SQLHSTMT is SQLHANDLE;
```

---

# 13. 为什么 SQLLEN 是 64 位？

这是 Windows 64-bit ODBC 中非常重要的一点。

ODBC：

```text
SQLINTEGER
```

是：

```text
32-bit
```

而：

```text
SQLLEN
SQLULEN
```

在 64-bit 平台上是：

```text
64-bit
```

因此不能简单地全部写成：

```ada
Interfaces.C.int
```

否则在：

```text
SQLBindParameter
SQLGetData
```

等函数中容易发生 ABI 不匹配。

---

# 14. ODBC Handle

ODBC 中最重要的三个句柄：

```text
Environment
Connection
Statement
```

分别对应：

```ada
SQLHENV
SQLHDBC
SQLHSTMT
```

关系：

```text
SQLHENV
   │
   └── SQLHDBC
           │
           └── SQLHSTMT
```

可以理解成：

```text
Environment
    │
    └── Database Connection
             │
             └── SQL Statement
```

---

# 15. SQLAllocHandle

Ada 声明：

```ada
function SQLAllocHandle
  (Handle_Type   : SQLSMALLINT;
   Input_Handle  : SQLHANDLE;
   Output_Handle : access SQLHANDLE)
   return SQLRETURN;
```

导入：

```ada
pragma Import
  (Stdcall,
   SQLAllocHandle,
   "SQLAllocHandle");
```

例如创建 Environment：

```ada
SQLAllocHandle
  (SQL_HANDLE_ENV,
   System.Null_Address,
   Environment'Access);
```

创建 Connection：

```ada
SQLAllocHandle
  (SQL_HANDLE_DBC,
   Environment,
   Connection'Access);
```

创建 Statement：

```ada
SQLAllocHandle
  (SQL_HANDLE_STMT,
   Connection,
   Statement'Access);
```

---

# 16. 为什么 Handle 要 `aliased`

例如：

```ada
Environment : aliased SQLHENV :=
  System.Null_Address;
```

然后：

```ada
Environment'Access
```

才能传给：

```ada
SQLAllocHandle
```

因为 C API 需要：

```c
SQLHANDLE *
```

也就是：

```text
指向 Handle 变量的指针
```

Ada 中对应：

```ada
access SQLHANDLE
```

因此变量必须允许取地址。

---

# 17. SQLSetEnvAttr

初始化 ODBC：

```ada
SQLSetEnvAttr
```

主要设置：

```text
SQL_ATTR_ODBC_VERSION
```

值：

```text
SQL_OV_ODBC3
```

本项目使用：

```ada
System'To_Address (SQL_OV_ODBC3)
```

这是一个非常容易踩坑的地方。

不能写成：

```ada
Version'Address
```

因为 ODBC 对：

```text
SQL_ATTR_ODBC_VERSION
```

的 `ValuePtr` 参数实际上要求的是：

```text
整数值作为指针值
```

而不是：

```text
指向整数变量的地址
```

最终：

```ada
Result :=
  SQLSetEnvAttr
    (Environment,
     SQL_ATTR_ODBC_VERSION,
     System'To_Address (SQL_OV_ODBC3),
     0);
```

运行结果：

```text
[1] Initializing ODBC...
OK
```

---

# 18. SQLDriverConnectA

连接 Firebird：

```ada
SQLDriverConnectA
```

Ada 声明：

```ada
function SQLDriverConnectA
  (Connection_Handle : SQLHDBC;
   Window_Handle     : System.Address;
   In_Connection     : System.Address;
   String_Length_1   : SQLSMALLINT;
   Out_Connection    : System.Address;
   Buffer_Length     : SQLSMALLINT;
   String_Length_2   : access SQLSMALLINT;
   Driver_Completion : SQLUSMALLINT)
   return SQLRETURN;
```

调用：

```ada
Result :=
  SQLDriverConnectA
    (Connection,
     System.Null_Address,
     Conn_C'Address,
     SQLSMALLINT (Conn_C'Length - 1),
     Out_C'Address,
     SQLSMALLINT (Out_C'Length),
     Out_Length'Access,
     SQL_DRIVER_NOPROMPT);
```

成功：

```text
Connected
```

---

# 19. ODBC 返回值

ODBC 常见返回值：

```ada
SQL_SUCCESS           : constant SQLRETURN := 0;
SQL_SUCCESS_WITH_INFO : constant SQLRETURN := 1;
SQL_ERROR             : constant SQLRETURN := -1;
SQL_INVALID_HANDLE    : constant SQLRETURN := -2;
SQL_NO_DATA           : constant SQLRETURN := 100;
```

通常判断：

```ada
if Result /= SQL_SUCCESS
  and then
     Result /= SQL_SUCCESS_WITH_INFO
then
   -- error
end if;
```

---

# 20. ODBC Diagnostics

这是调试 ODBC 最重要的机制之一。

如果只打印：

```text
SQLDriverConnectA return = -1
```

信息非常少。

所以项目实现：

```ada
Print_Diagnostics
```

内部调用：

```ada
SQLGetDiagRecA
```

获取：

```text
SQLSTATE
Native Error
Message
```

例如本项目实际遇到：

```text
SQLSTATE     : IM002
Native Error : 0
Message      : [Microsoft][ODBC 驱动程序管理器]
               未发现数据源名称并且未指定默认驱动程序
```

立即定位到：

```text
DRIVER 名称错误
```

---

# 21. SQLSTATE IM002

这个错误：

```text
IM002
```

通常表示：

```text
Data source name not found
and no default driver specified
```

中文：

```text
未发现数据源名称并且未指定默认驱动程序
```

常见原因：

1. `DRIVER=` 名称错误

2. DSN 不存在

3. 32-bit / 64-bit 不匹配

4. ODBC Driver 没安装

5. Driver 没有正确注册

本项目实际原因是：

```text
错误：
Firebird/InterBase(r) driver

正确：
Firebird ODBC Driver
```

---

# 22. SQLExecDirect

执行普通 SQL：

```ada
ODBC.Exec
  ("CREATE TABLE ...");
```

内部调用：

```ada
SQLExecDirectA
```

例如：

```ada
ODBC.Exec
  ("CREATE TABLE ADA_FB_DEMO "
   & "(ID INTEGER NOT NULL PRIMARY KEY, "
   & "NAME VARCHAR(100))");
```

数据库执行：

```sql
CREATE TABLE ADA_FB_DEMO
(
    ID INTEGER NOT NULL PRIMARY KEY,
    NAME VARCHAR(100)
);
```

---

# 23. DROP TABLE

测试程序启动时：

```ada
begin

   ODBC.Exec
     ("DROP TABLE ADA_FB_DEMO");

exception

   when others =>
      null;

end;
```

这是为了让程序可以重复运行。

如果第一次运行：

```text
ADA_FB_DEMO
```

不存在，会产生错误。

这里暂时忽略。

然后重新：

```sql
CREATE TABLE ADA_FB_DEMO ...
```

---

# 24. SQLPrepare

参数化 SQL：

```sql
INSERT INTO ADA_FB_DEMO
(ID, NAME)
VALUES (?, ?)
```

Ada：

```ada
ODBC.Prepare
  ("INSERT INTO ADA_FB_DEMO (ID, NAME) "
   & "VALUES (?, ?)");
```

内部调用：

```ada
SQLPrepareA
```

---

# 25. 为什么使用参数化 SQL

不要把数据直接拼接到 SQL：

```ada
"INSERT INTO ... VALUES (" &
  Integer'Image (ID) &
  ", '" &
  Name &
  "')"
```

更好的方式：

```sql
INSERT INTO ADA_FB_DEMO
(ID, NAME)
VALUES (?, ?)
```

然后：

```text
参数 1 → ID
参数 2 → Name
```

优点：

- 避免 SQL Injection

- 不需要手动转义字符串

- 类型处理更可靠

- 更适合以后封装数据库层

- SQL 与数据分离

---

# 26. SQLBindParameter

项目提供：

```ada
Bind_Integer_Address
```

和：

```ada
Bind_String_Address
```

例如：

```ada
ODBC.Bind_Integer_Address
  (1,
   ID'Address,
   ID_Indicator'Address);
```

第二个：

```ada
ODBC.Bind_String_Address
  (2,
   Name'Address,
   ODBC.SQLLEN (Name'Length),
   ODBC.SQLULEN (Name'Length - 1),
   Name_Indicator'Address);
```

---

# 27. 参数缓冲区生命周期

这是之前出现：

```text
STORAGE_ERROR
stack overflow or erroneous memory access
```

的重要原因之一。

错误思路：

```ada
procedure Bind_String is

   Value : aliased char_array :=
     To_C ("Alice");

   SQLBindParameter (... Value'Address ...);

end Bind_String;
```

当：

```text
Bind_String
```

返回以后：

```text
Value
```

已经离开作用域。

但是：

```text
SQLExecute
```

可能还要访问这个地址。

于是：

```text
悬空地址
   ↓
非法内存访问
   ↓
STORAGE_ERROR
```

正确做法是让参数变量存在于 `main.adb`：

```ada
ID : aliased ODBC.SQLINTEGER := 1;

Name : aliased char_array :=
  To_C ("Alice");
```

然后：

```text
ID
Name
   │
   │ SQLBindParameter
   ▼
SQLExecute
```

整个过程中变量都还活着。

这是 Ada 调用 C API 时非常重要的内存生命周期原则。

---

# 28. Integer 参数

定义：

```ada
ID : aliased ODBC.SQLINTEGER := 1;
```

对应 Firebird：

```sql
ID INTEGER
```

绑定：

```ada
ODBC.Bind_Integer_Address
  (1,
   ID'Address,
   ID_Indicator'Address);
```

内部：

```ada
SQL_C_LONG
```

对应：

```text
C int
```

SQL 类型：

```ada
SQL_INTEGER
```

---

# 29. String 参数

定义：

```ada
Name : aliased char_array :=
  To_C ("Alice");
```

`To_C` 会生成 C 风格字符串：

```text
Alice\0
```

绑定：

```ada
ODBC.Bind_String_Address
  (2,
   Name'Address,
   ODBC.SQLLEN (Name'Length),
   ODBC.SQLULEN (Name'Length - 1),
   Name_Indicator'Address);
```

对应：

```text
Ada char_array
       ↓
C char buffer
       ↓
SQL_C_CHAR
       ↓
SQL_VARCHAR
       ↓
Firebird VARCHAR
```

---

# 30. SQLExecute

参数绑定以后：

```ada
ODBC.Execute;
```

内部：

```ada
SQLExecute (Statement)
```

成功：

```text
INSERT OK
```

---

# 31. COMMIT

程序执行：

```ada
ODBC.Commit;
```

内部：

```ada
SQLEndTran
  (SQL_HANDLE_DBC,
   Connection,
   SQL_COMMIT);
```

对应：

```sql
COMMIT;
```

---

# 32. ROLLBACK

发生异常：

```ada
ODBC.Rollback;
```

内部：

```ada
SQLEndTran
  (SQL_HANDLE_DBC,
   Connection,
   SQL_ROLLBACK);
```

对应：

```sql
ROLLBACK;
```

---

# 33. 为什么不能在初始化失败时 Rollback

之前出现：

```text
SQLEndTran ROLLBACK return = -2
```

原因是：

```text
SQLSetEnvAttr
       ↓
失败
       ↓
Connection 根本没有建立
       ↓
异常处理却执行 SQLEndTran
       ↓
SQL_INVALID_HANDLE (-2)
```

所以现在使用：

```ada
Connected : Boolean := False;
```

成功连接：

```ada
Connected := True;
```

异常时：

```ada
if Connected then
   ODBC.Rollback;
end if;
```

这样更合理。

---

# 34. Disconnect

最终需要释放：

```text
Statement
Connection
Environment
```

顺序：

```text
Statement
   ↓
Connection
   ↓
Environment
```

对应：

```ada
SQLFreeHandle
```

以及：

```ada
SQLDisconnect
```

---

# 35. 完整程序执行流程

现在整个程序：

```text
main
 │
 ├── Initialize
 │      │
 │      ├── SQLAllocHandle ENV
 │      └── SQLSetEnvAttr
 │
 ├── Connect
 │      │
 │      ├── SQLAllocHandle DBC
 │      └── SQLDriverConnectA
 │
 ├── DROP TABLE
 │      └── SQLExecDirectA
 │
 ├── CREATE TABLE
 │      └── SQLExecDirectA
 │
 ├── Prepare
 │      └── SQLPrepareA
 │
 ├── Bind ID
 │      └── SQLBindParameter
 │
 ├── Bind Name
 │      └── SQLBindParameter
 │
 ├── Execute
 │      └── SQLExecute
 │
 ├── Commit
 │      └── SQLEndTran
 │
 └── Disconnect
        ├── SQLFreeHandle STMT
        ├── SQLDisconnect
        ├── SQLFreeHandle DBC
        └── SQLFreeHandle ENV
```

---

# 36. 编译

进入项目目录：

```nu
cd F:\proj-2025\ada\ada_odbc_firebird
```

编译：

```nu
gprbuild -P ada_odbc_firebird.gpr
```

成功后：

```text
bin/main.exe
```

运行：

```nu
.\bin\main.exe
```

---

# 37. 正常输出

最终正常运行应该类似：

```text
========================================
 Ada + ODBC + Firebird 5
========================================

[1] Initializing ODBC...
OK

[2] Connecting to Firebird...
Connected

[3] Creating test table...
Table created

[4] INSERT using parameters...
INSERT OK

[5] COMMIT...
COMMIT OK

========================================
Done
========================================
```

---

# 38. 当前测试表

程序创建：

```sql
CREATE TABLE ADA_FB_DEMO
(
    ID INTEGER NOT NULL PRIMARY KEY,
    NAME VARCHAR(100)
);
```

插入：

```text
ID   NAME
1    Alice
```

等价 SQL：

```sql
INSERT INTO ADA_FB_DEMO
(ID, NAME)
VALUES
(1, 'Alice');
```

---

# 39. 这个项目目前完成了什么

目前已经验证了完整的：

```text
Ada
 ↓
ODBC
 ↓
Firebird
```

通信链路。

已经涉及：

- ODBC Environment

- ODBC Connection

- ODBC Statement

- ODBC Driver

- Driver Manager

- Firebird 5

- SQLExecDirect

- SQLPrepare

- SQLBindParameter

- SQLExecute

- SQLEndTran

- SQLGetDiagRec

- COMMIT

- ROLLBACK

- C/Ada ABI

- 64-bit `SQLLEN`

- C 字符串

- Handle 生命周期

- 参数缓冲区生命周期

- ODBC 错误诊断

这已经可以作为后续开发数据库应用的基础层。

---

# 40. 后续建议的项目结构

如果继续开发，我建议不要把所有数据库操作都塞进 `odbc.adb`。

下一步可以逐渐变成：

```text
ada_odbc_firebird/
│
├── ada_odbc_firebird.gpr
│
├── db/
│   ├── db.ads
│   ├── db.adb
│   ├── db_types.ads
│   └── db_errors.ads
│
├── models/
│   ├── books.ads
│   ├── members.ads
│   └── loans.ads
│
├── services/
│   ├── book_service.ads
│   ├── member_service.ads
│   └── loan_service.ads
│
├── sql/
│   ├── 001_schema.sql
│   └── 002_seed.sql
│
└── main.adb
```

最终形成：

```text
                 main.adb
                    │
                    ▼
              Service Layer
             /      |       \
            /       |        \
         Books   Members    Loans
            \       |        /
             \      |       /
              ▼     ▼      ▼
                 DB Layer
                    │
                    ▼
               ODBC Wrapper
                    │
                    ▼
                odbc32.dll
                    │
                    ▼
          Firebird ODBC Driver
                    │
                    ▼
                Firebird 5
```

这样以后做你之前计划的**图书管理系统**就比较合适：

```text
图书
会员
借阅
归还
事务
COMMIT
ROLLBACK
参数绑定
SELECT
UPDATE
DELETE
```

都可以建立在现在已经跑通的 ODBC 基础之上。
