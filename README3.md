下面我把刚才的 **Ada + ODBC + Firebird 5** 项目整理成一份完整的技术文档，重点解释：

1. 项目结构

2. GPR 项目文件

3. `odbc.ads`

4. `odbc.adb`

5. `main.adb`

6. Ada → ODBC → Firebird 的完整执行链

7. 每个 ODBC 函数的作用

8. 参数绑定为什么需要 `aliased`、`Address`

9. `SQLSetEnvAttr` 为什么必须这样传参

10. `SQLDriverConnectA` 如何连接 Firebird

11. `SQLPrepare` / `SQLBindParameter` / `SQLExecute` 的工作过程

12. `COMMIT` / `ROLLBACK`

13. 错误诊断机制

14. 编译、运行流程

15. 项目目前的不足以及下一步如何扩展成完整数据库封装

---

# Ada + ODBC + Firebird 5 完整项目文档

## 1. 项目简介

本项目演示：

> **Ada 程序 → Windows ODBC API → Firebird ODBC Driver → Firebird 5 数据库**

最终实现：

- 初始化 ODBC

- 创建 ODBC Environment

- 设置 ODBC 版本

- 建立数据库连接

- 创建数据库表

- 使用参数化 SQL

- 绑定 Ada 变量

- 执行 `INSERT`

- `COMMIT`

- 错误诊断

- 断开连接

- 释放 ODBC 资源

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

整体架构：

```text
┌──────────────────────┐
│      main.adb        │
│                      │
│  业务逻辑 / SQL      │
└──────────┬───────────┘
           │
           │ Ada procedure/function
           ▼
┌──────────────────────┐
│      odbc.ads        │
│                      │
│ ODBC API 声明        │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│      odbc.adb        │
│                      │
│ Ada → C/ODBC 封装     │
└──────────┬───────────┘
           │
           │ pragma Import
           ▼
┌──────────────────────┐
│       odbc32.dll     │
│ Windows ODBC Manager │
└──────────┬───────────┘
           │
           ▼
┌────────────────────────────┐
│ Firebird ODBC Driver 64bit │
└────────────┬───────────────┘
             │
             ▼
┌──────────────────────┐
│      Firebird 5      │
│      test.fdb        │
└──────────────────────┘
```

---

# 2. 环境

当前项目环境：

```text
Windows 64-bit
GNAT Native 16.1.0
GPRbuild
Firebird 5
Firebird ODBC Driver 64-bit
```

数据库：

```text
localhost:F:\proj-2025\ada\data\test.fdb
```

账号：

```text
SYSDBA
```

密码：

```text
123456
```

ODBC Driver 名称：

```text
Firebird ODBC Driver
```

这里非常重要。

之前连接失败：

```text
IM002
[Microsoft][ODBC 驱动程序管理器]
未发现数据源名称并且未指定默认驱动程序
```

原因就是 Driver 名称写错。

正确：

```text
DRIVER=Firebird ODBC Driver;
```

而不是：

```text
DRIVER=Firebird/InterBase(r) driver;
```

---

# 3. GPR 项目文件

文件：

```text
ada_odbc_firebird.gpr
```

内容：

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

---

# 4. GPR 文件逐行解释

## 4.1 project

```ada
project Ada_Odbc_Firebird is
```

定义一个 GPRbuild 项目。

相当于告诉 GPRbuild：

> 这个目录是一个 Ada 工程。

---

## 4.2 Languages

```ada
for Languages use ("Ada");
```

表示项目使用 Ada。

---

## 4.3 Main

```ada
for Main use ("main.adb");
```

指定程序入口。

也就是说最终生成：

```text
main.exe
```

---

## 4.4 Source_Dirs

```ada
for Source_Dirs use (".");
```

告诉 GPRbuild：

> Ada 源文件就在当前目录。

所以：

```text
main.adb
odbc.ads
odbc.adb
```

都会被找到。

---

# 5. Object_Dir

```ada
for Object_Dir use "obj";
```

编译产生的中间文件放：

```text
obj/
```

例如：

```text
obj/main.o
obj/main.ali
obj/odbc.o
obj/odbc.ali
```

---

# 6. Exec_Dir

```ada
for Exec_Dir use "bin";
```

最终 EXE 放：

```text
bin/
```

因此：

```text
bin/main.exe
```

---

# 7. 为什么要链接 `odbc32`

```ada
package Linker is
   for Default_Switches ("Ada") use ("-lodbc32");
end Linker;
```

这里：

```text
-lodbc32
```

表示链接 Windows ODBC Manager：

```text
odbc32.dll
```

注意：

这里并不是直接链接 Firebird。

结构实际上是：

```text
Ada
 │
 ▼
odbc32.dll
 │
 ▼
Firebird ODBC Driver
 │
 ▼
Firebird
```

---

# 8. `odbc.ads`

`odbc.ads` 是 ODBC 的 Ada 接口声明。

它做的事情是：

> 把 C/ODBC API 的函数和类型告诉 Ada 编译器。

例如：

```ada
function SQLAllocHandle
  (...)
  return SQLRETURN;

pragma Import (Stdcall, SQLAllocHandle, "SQLAllocHandle");
```

意思是：

> Ada 中声明一个叫 `SQLAllocHandle` 的函数，但真正的实现来自外部 DLL。

---

# 9. 为什么需要 `pragma Import`

这是整个项目非常重要的一部分。

例如：

```ada
function SQLDisconnect
  (Connection_Handle : SQLHDBC)
  return SQLRETURN;

pragma Import (Stdcall, SQLDisconnect, "SQLDisconnect");
```

Ada 本身没有实现：

```text
SQLDisconnect
```

真正实现位于 Windows ODBC DLL。

所以：

```ada
pragma Import (...)
```

相当于告诉 Ada：

```text
这个函数不是 Ada 实现的。

去外部库里找它。
```

可以理解成：

```text
Ada function declaration
        │
        │ pragma Import
        ▼
Windows DLL
        │
        ▼
真正的 C 函数
```

---

# 10. `SQLHANDLE`

```ada
subtype SQLHANDLE is System.Address;
```

ODBC 中大量对象使用 Handle：

```text
Environment Handle
Connection Handle
Statement Handle
```

Ada 中简单地用：

```ada
System.Address
```

表示。

因此：

```ada
SQLHENV
SQLHDBC
SQLHSTMT
```

实际上都是：

```ada
System.Address
```

---

# 11. 三个核心 Handle

ODBC 最重要的是三个对象：

```text
Environment
Connection
Statement
```

分别对应：

```text
SQLHENV
SQLHDBC
SQLHSTMT
```

可以理解成：

### Environment

整个 ODBC 环境。

```text
ODBC Environment
```

### Connection

数据库连接。

```text
Firebird Connection
```

### Statement

SQL 执行环境。

```text
SQL Statement
```

结构：

```text
Environment
    │
    └── Connection
           │
           ├── Statement
           │
           ├── Statement
           │
           └── Statement
```

---

# 12. `SQLRETURN`

```ada
subtype SQLRETURN is SQLSMALLINT;
```

ODBC API 通常通过返回值表示结果。

主要值：

```ada
SQL_SUCCESS           : constant SQLRETURN := 0;
SQL_SUCCESS_WITH_INFO : constant SQLRETURN := 1;
SQL_ERROR             : constant SQLRETURN := -1;
SQL_INVALID_HANDLE    : constant SQLRETURN := -2;
SQL_NO_DATA           : constant SQLRETURN := 100;
```

所以：

```ada
Result := SQLExecute (...);
```

之后需要检查：

```ada
if Result /= SQL_SUCCESS
  and then Result /= SQL_SUCCESS_WITH_INFO
then
   ...
end if;
```

---

# 13. `SQLAllocHandle`

声明：

```ada
function SQLAllocHandle
  (Handle_Type   : SQLSMALLINT;
   Input_Handle  : SQLHANDLE;
   Output_Handle : access SQLHANDLE)
   return SQLRETURN;
```

作用：

> 创建 ODBC Handle。

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

关系：

```text
SQLAllocHandle
      │
      ├── ENV
      │
      ├── DBC
      │
      └── STMT
```

---

# 14. `SQLSetEnvAttr`

```ada
function SQLSetEnvAttr
  (...)
  return SQLRETURN;
```

作用：

> 设置 ODBC Environment 属性。

本项目：

```ada
SQLSetEnvAttr
  (Environment,
   SQL_ATTR_ODBC_VERSION,
   System'To_Address (SQL_OV_ODBC3),
   0);
```

告诉 ODBC：

```text
我要使用 ODBC 3.x API。
```

---

# 15. 为什么这里不能直接传整数

这是之前调试过程中非常重要的一点。

ODBC C API 类似：

```c
SQLSetEnvAttr(
    environment,
    SQL_ATTR_ODBC_VERSION,
    (SQLPOINTER)SQL_OV_ODBC3,
    0
);
```

第三个参数不是：

```text
Integer
```

而是：

```text
pointer
```

所以 Ada 声明：

```ada
Value : System.Address;
```

调用：

```ada
System'To_Address (SQL_OV_ODBC3)
```

把整数：

```text
3
```

转换成 ODBC 需要的地址值。

因此：

```ada
System'To_Address (SQL_OV_ODBC3)
```

是本项目能够正常初始化 ODBC 的关键之一。

---

# 16. `SQLDriverConnectA`

声明：

```ada
function SQLDriverConnectA
  (...)
  return SQLRETURN;
```

作用：

> 建立数据库连接。

连接字符串：

```ada
Connection_String : constant String :=
  "DRIVER=Firebird ODBC Driver;"
  & "DBNAME=localhost:F:\proj-2025\ada\data\test.fdb;"
  & "UID=SYSDBA;"
  & "PWD=123456;";
```

这里包含：

```text
DRIVER
DBNAME
UID
PWD
```

---

# 17. DRIVER

```text
DRIVER=Firebird ODBC Driver;
```

告诉 Windows ODBC Manager：

> 使用这个 ODBC Driver。

ODBC Manager 会查找系统中注册的：

```text
Firebird ODBC Driver
```

然后加载对应的驱动。

---

# 18. DBNAME

```text
DBNAME=localhost:F:\proj-2025\ada\data\test.fdb;
```

表示 Firebird 数据库。

其中：

```text
localhost
```

表示 Firebird Server。

```text
F:\proj-2025\ada\data\test.fdb
```

表示数据库文件。

---

# 19. UID / PWD

```text
UID=SYSDBA;
PWD=123456;
```

数据库登录用户名和密码。

---

# 20. 连接过程

执行：

```ada
ODBC.Connect (Connection_String);
```

实际上经历：

```text
main.adb
   │
   ▼
ODBC.Connect
   │
   ▼
SQLAllocHandle(DBC)
   │
   ▼
SQLDriverConnectA
   │
   ▼
Windows ODBC Manager
   │
   ▼
Firebird ODBC Driver
   │
   ▼
Firebird Server
   │
   ▼
test.fdb
```

---

# 21. `SQLDisconnect`

```ada
function SQLDisconnect
  (Connection_Handle : SQLHDBC)
  return SQLRETURN;
```

作用：

> 断开数据库连接。

注意：

它只是：

```text
断开连接
```

并不是：

```text
释放 Connection Handle
```

所以正常生命周期是：

```text
SQLDisconnect
       ↓
SQLFreeHandle(SQL_HANDLE_DBC)
```

---

# 22. `SQLFreeHandle`

作用：

> 释放 ODBC Handle。

例如：

```ada
SQLFreeHandle
  (SQL_HANDLE_STMT,
   Statement);
```

释放 Statement。

然后：

```ada
SQLFreeHandle
  (SQL_HANDLE_DBC,
   Connection);
```

释放 Connection。

最后：

```ada
SQLFreeHandle
  (SQL_HANDLE_ENV,
   Environment);
```

释放 Environment。

---

# 23. Handle 生命周期

完整生命周期：

```text
SQLAllocHandle ENV
        │
        ▼
SQLSetEnvAttr
        │
        ▼
SQLAllocHandle DBC
        │
        ▼
SQLDriverConnect
        │
        ▼
SQLAllocHandle STMT
        │
        ▼
SQLPrepare / SQLExecDirect
        │
        ▼
SQLExecute
        │
        ▼
SQLFreeHandle STMT
        │
        ▼
SQLDisconnect
        │
        ▼
SQLFreeHandle DBC
        │
        ▼
SQLFreeHandle ENV
```

这是整个程序最核心的生命周期。

---

# 24. `SQLExecDirectA`

声明：

```ada
function SQLExecDirectA
  (...)
  return SQLRETURN;
```

作用：

> 直接执行一条 SQL。

例如：

```ada
ODBC.Exec
  ("CREATE TABLE ADA_FB_DEMO "
   & "(ID INTEGER NOT NULL PRIMARY KEY, "
   & "NAME VARCHAR(100))");
```

内部：

```text
SQLExecDirectA
       │
       ▼
Firebird ODBC Driver
       │
       ▼
Firebird SQL Engine
```

适合：

```sql
CREATE TABLE
DROP TABLE
ALTER TABLE
CREATE INDEX
```

等不需要参数的 SQL。

---

# 25. `SQLPrepareA`

声明：

```ada
function SQLPrepareA
  (...)
  return SQLRETURN;
```

作用：

> 预编译/准备 SQL。

例如：

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

这里：

```text
?
?
```

是参数占位符。

---

# 26. 为什么不直接拼接字符串

不推荐：

```ada
"INSERT INTO table VALUES ("
& Integer'Image (ID)
& ", '"
& Name
& "')"
```

因为会产生：

- SQL Injection

- 引号处理问题

- 类型转换问题

- 日期问题

- 编码问题

更好的方法：

```sql
INSERT INTO table
VALUES (?, ?)
```

然后：

```text
SQLBindParameter
```

绑定 Ada 变量。

---

# 27. `SQLBindParameter`

这是参数化 SQL 的核心。

声明：

```ada
function SQLBindParameter
  (...)
  return SQLRETURN;
```

例如：

```ada
ODBC.Bind_Integer_Address
  (1,
   ID'Address,
   ID_Indicator'Address);
```

绑定：

```text
第 1 个 ?
```

到：

```text
ID
```

第二个：

```ada
ODBC.Bind_String_Address
  (2,
   Name'Address,
   ...);
```

绑定：

```text
第 2 个 ?
```

到：

```text
Name
```

---

# 28. `SQLBindParameter` 的参数

核心参数：

```text
Parameter_Number
Input_Output
Value_Type
Parameter_Type
Column_Size
Decimal_Digits
Parameter_Value
Buffer_Length
StrLen_Or_Ind
```

例如：

```ada
SQLBindParameter
  (Statement,
   1,
   SQL_PARAM_INPUT,
   SQL_C_LONG,
   SQL_INTEGER,
   10,
   0,
   Value_Address,
   4,
   Indicator_Address);
```

---

# 29. `Value_Type`

```ada
SQL_C_LONG
```

表示：

> Ada/C 内存中的值按照 C `long` / ODBC C 整数类型解释。

例如：

```text
Ada Integer
      ↓
C integer representation
      ↓
SQL_C_LONG
```

---

# 30. `Parameter_Type`

```ada
SQL_INTEGER
```

表示：

> 数据库中的参数类型是 SQL INTEGER。

所以：

```text
SQL_C_LONG
```

和：

```text
SQL_INTEGER
```

含义不同。

前者：

```text
客户端内存类型
```

后者：

```text
数据库 SQL 类型
```

可以理解为：

```text
Ada 内存
   │
   │ SQL_C_LONG
   ▼
ODBC
   │
   │ SQL_INTEGER
   ▼
Firebird INTEGER
```

---

# 31. `aliased` 为什么重要

例如：

```ada
ID : aliased ODBC.SQLINTEGER := 1;
```

为什么不是：

```ada
ID : ODBC.SQLINTEGER := 1;
```

因为我们需要：

```ada
ID'Address
```

把变量地址交给 C/ODBC。

`aliased` 告诉 Ada：

> 这个对象需要稳定的地址，可以通过 `'Address` 获取并用于外部接口。

所以：

```ada
ID'Address
```

可以传给：

```ada
SQLBindParameter
```

---

# 32. `Address`

例如：

```ada
ID'Address
```

取得变量在内存中的地址。

可以理解成：

```text
ID
┌───────────┐
│     1     │
└───────────┘
      ▲
      │
      │ Address
      │
      ▼
ODBC
```

ODBC 不会拿 Ada 的变量名。

它只知道：

```text
内存地址
```

---

# 33. String 参数

字符串：

```ada
Name : aliased char_array :=
  To_C ("Alice");
```

最终内存类似：

```text
A
l
i
c
e
\0
```

C 字符串需要：

```text
NUL terminator
```

所以：

```ada
To_C ("Alice")
```

非常重要。

---

# 34. `SQLExecute`

准备：

```ada
ODBC.Prepare (...);
```

绑定：

```ada
ODBC.Bind_Integer_Address (...);
ODBC.Bind_String_Address (...);
```

最后：

```ada
ODBC.Execute;
```

内部：

```text
SQLPrepare
     │
     ▼
INSERT INTO ... VALUES (?, ?)
     │
     ▼
SQLBindParameter
     │
     ├── ? ← ID
     │
     └── ? ← Name
     │
     ▼
SQLExecute
     │
     ▼
Firebird
```

---

# 35. `SQLFetch`

声明：

```ada
function SQLFetch
  (Statement_Handle : SQLHSTMT)
  return SQLRETURN;
```

作用：

> 从 SELECT 查询结果中取得下一行。

例如：

```sql
SELECT ID, NAME
FROM ADA_FB_DEMO
```

第一次：

```ada
SQLFetch
```

取得：

```text
1 Alice
```

第二次：

```ada
SQLFetch
```

取得：

```text
2 Bob
```

没有数据：

```text
SQL_NO_DATA
```

---

# 36. `SQLGetData`

声明：

```ada
function SQLGetData
  (...)
  return SQLRETURN;
```

作用：

> 从当前 Fetch 到的行中读取某个字段。

例如：

```ada
Get_String (2)
```

表示：

```text
读取第 2 列
```

例如：

```text
SELECT ID, NAME
```

那么：

```text
Column 1 → ID
Column 2 → NAME
```

---

# 37. SELECT 的完整过程

未来加入 SELECT 时：

```text
SQLPrepare
     │
     ▼
SELECT ID, NAME FROM ...
     │
     ▼
SQLExecute
     │
     ▼
SQLFetch
     │
     ▼
SQLGetData(1)
SQLGetData(2)
     │
     ▼
下一行
     │
     ▼
SQLFetch
     │
     ▼
SQL_NO_DATA
```

---

# 38. `SQLEndTran`

声明：

```ada
function SQLEndTran
  (...)
  return SQLRETURN;
```

作用：

> 结束当前事务。

有两个主要操作：

```ada
SQL_COMMIT
SQL_ROLLBACK
```

---

# 39. `Commit`

代码：

```ada
procedure Commit is
begin
   SQLEndTran
     (SQL_HANDLE_DBC,
      Connection,
      SQL_COMMIT);
end Commit;
```

作用：

```text
提交当前事务
```

例如：

```text
INSERT
   ↓
事务中
   ↓
COMMIT
   ↓
正式提交
```

---

# 40. `Rollback`

```ada
SQLEndTran
  (SQL_HANDLE_DBC,
   Connection,
   SQL_ROLLBACK);
```

作用：

> 撤销当前事务中尚未提交的修改。

例如：

```text
INSERT
UPDATE
DELETE
   ↓
发生错误
   ↓
ROLLBACK
   ↓
撤销
```

---

# 41. 为什么事务很重要

例如图书管理系统：

```text
借书
```

可能需要：

```sql
UPDATE books ...
UPDATE members ...
INSERT INTO loans ...
```

三个操作必须作为一个整体。

理想过程：

```text
BEGIN
   │
   ├── UPDATE books
   │
   ├── UPDATE members
   │
   └── INSERT loans
        │
        ▼
      COMMIT
```

如果中途失败：

```text
ROLLBACK
```

这样数据库不会出现：

```text
书已经借出
但是借阅记录没有创建
```

这样的半完成状态。

---

# 42. `SQLGetDiagRecA`

这是错误诊断函数。

声明：

```ada
function SQLGetDiagRecA
  (...)
  return SQLRETURN;
```

ODBC API 很多时候：

```text
函数返回 SQL_ERROR
```

但：

```text
SQL_ERROR
```

本身并不能告诉我们具体原因。

所以需要：

```ada
SQLGetDiagRecA
```

获取：

```text
SQLSTATE
Native Error
Message
```

---

# 43. 错误输出

例如：

```text
SQLSTATE     : IM002
Native Error : 0
Message      :
[Microsoft][ODBC 驱动程序管理器]
未发现数据源名称并且未指定默认驱动程序
```

其中：

```text
IM002
```

就是非常重要的 SQLSTATE。

---

# 44. 为什么之前 IM002

之前：

```text
SQLDriverConnectA
```

失败。

错误：

```text
IM002
```

原因不是 Ada 本身。

而是：

```text
ODBC Manager 找不到指定 Driver
```

之前使用：

```text
DRIVER=Firebird/InterBase(r) driver;
```

系统实际注册的是：

```text
Firebird ODBC Driver
```

因此修改为：

```text
DRIVER=Firebird ODBC Driver;
```

之后连接成功。

这也是学习 ODBC 时非常典型的问题：

```text
Ada API 没问题
ODBC API 没问题
数据库也没问题
但是 Driver 名称不匹配
```

---

# 45. `Print_Diagnostics`

项目封装了：

```ada
procedure Print_Diagnostics
  (Handle_Type : SQLSMALLINT;
   Handle      : SQLHANDLE);
```

它循环调用：

```ada
SQLGetDiagRecA
```

直到：

```text
SQL_NO_DATA
```

这样一个 ODBC 操作出现多个诊断信息时，也可以全部打印。

---

# 46. `main.adb` 的作用

`main.adb` 是：

> 应用程序层。

它不应该直接到处调用：

```text
SQLAllocHandle
SQLDriverConnectA
SQLBindParameter
```

而是调用我们封装好的：

```ada
ODBC.Initialize;
ODBC.Connect;
ODBC.Exec;
ODBC.Prepare;
ODBC.Bind_Integer_Address;
ODBC.Bind_String_Address;
ODBC.Execute;
ODBC.Commit;
ODBC.Disconnect;
```

因此形成：

```text
main.adb
    │
    ▼
ODBC abstraction
    │
    ▼
ODBC API
```

这样以后开发图书管理系统会方便很多。

---

# 47. main 的第一步

```ada
ODBC.Initialize;
```

实际：

```text
SQLAllocHandle(ENV)
        ↓
SQLSetEnvAttr
```

建立：

```text
Environment
```

---

# 48. 第二步：Connect

```ada
ODBC.Connect (Connection_String);
```

实际：

```text
SQLAllocHandle(DBC)
        ↓
SQLDriverConnectA
        ↓
Firebird ODBC Driver
        ↓
Firebird
```

---

# 49. 第三步：创建表

代码：

```ada
ODBC.Exec
  ("CREATE TABLE ADA_FB_DEMO "
   & "(ID INTEGER NOT NULL PRIMARY KEY, "
   & "NAME VARCHAR(100))");
```

最终 SQL：

```sql
CREATE TABLE ADA_FB_DEMO
(
    ID INTEGER NOT NULL PRIMARY KEY,
    NAME VARCHAR(100)
);
```

数据库创建：

```text
ADA_FB_DEMO
├── ID
└── NAME
```

---

# 50. 为什么先 DROP

代码：

```ada
begin
   ODBC.Exec ("DROP TABLE ADA_FB_DEMO");
exception
   when others =>
      null;
end;
```

目的是：

> 每次运行程序时先删除旧测试表。

这样：

```text
第一次运行
DROP → 表不存在
CREATE → 创建

第二次运行
DROP → 删除旧表
CREATE → 创建新表
```

方便测试。

正式项目不能这样写，因为会删除生产数据。

---

# 51. INSERT

SQL：

```sql
INSERT INTO ADA_FB_DEMO
(ID, NAME)
VALUES (?, ?)
```

参数：

```text
? 1 → ID
? 2 → NAME
```

Ada：

```ada
ID : aliased ODBC.SQLINTEGER := 1;
```

和：

```ada
Name : aliased char_array :=
  To_C ("Alice");
```

---

# 52. 参数绑定

第一个：

```ada
ODBC.Bind_Integer_Address
  (1,
   ID'Address,
   ID_Indicator'Address);
```

意思：

```text
SQL 参数 1
        ↓
ID
```

第二个：

```ada
ODBC.Bind_String_Address
  (2,
   Name'Address,
   ...);
```

意思：

```text
SQL 参数 2
        ↓
Name
```

---

# 53. Execute

```ada
ODBC.Execute;
```

此时：

```text
SQLPrepare
     ↓
SQLBindParameter
     ↓
SQLBindParameter
     ↓
SQLExecute
```

数据库执行：

```sql
INSERT INTO ADA_FB_DEMO
(ID, NAME)
VALUES (1, 'Alice');
```

---

# 54. COMMIT

```ada
ODBC.Commit;
```

最终：

```text
SQLEndTran
     │
     └── SQL_COMMIT
```

数据库正式保存：

```text
ID     NAME
----------------
1      Alice
```

---

# 55. 完整执行过程

整个程序可以简化成：

```text
main
 │
 ├── ODBC.Initialize
 │      │
 │      ├── SQLAllocHandle(ENV)
 │      └── SQLSetEnvAttr
 │
 ├── ODBC.Connect
 │      │
 │      ├── SQLAllocHandle(DBC)
 │      └── SQLDriverConnectA
 │
 ├── ODBC.Exec
 │      │
 │      └── SQLExecDirectA
 │              │
 │              └── CREATE TABLE
 │
 ├── ODBC.Prepare
 │      │
 │      └── SQLPrepareA
 │
 ├── Bind ID
 │      │
 │      └── SQLBindParameter
 │
 ├── Bind Name
 │      │
 │      └── SQLBindParameter
 │
 ├── ODBC.Execute
 │      │
 │      └── SQLExecute
 │
 ├── ODBC.Commit
 │      │
 │      └── SQLEndTran(COMMIT)
 │
 └── ODBC.Disconnect
        │
        ├── SQLDisconnect
        ├── SQLFreeHandle(DBC)
        └── SQLFreeHandle(ENV)
```

---

# 56. 从程序启动到 Firebird 的完整调用链

更底层一点：

```text
main.adb
   │
   │ ODBC.Connect
   ▼
odbc.adb
   │
   │ SQLDriverConnectA
   ▼
odbc32.dll
   │
   │ ODBC Driver Manager
   ▼
Firebird ODBC Driver
   │
   │ Firebird wire protocol
   ▼
Firebird Server
   │
   ▼
test.fdb
```

所以这里其实存在 **4 层**：

```text
第 1 层：Ada 应用
        │
第 2 层：Ada ODBC Binding
        │
第 3 层：Windows ODBC
        │
第 4 层：Firebird Driver + Firebird
```

---

# 57. 为什么不直接调用 Firebird

理论上可以使用 Firebird 原生客户端 API。

那会变成：

```text
Ada
 ↓
Firebird Client API
 ↓
Firebird
```

但是当前项目选择：

```text
Ada
 ↓
ODBC
 ↓
Firebird ODBC Driver
 ↓
Firebird
```

优点是以后可以切换数据库。

例如：

```text
Firebird
PostgreSQL
SQL Server
MySQL
Oracle
```

只要提供对应 ODBC Driver，应用层可以继续使用 ODBC。

---

# 58. 当前 ODBC 封装层的意义

现在：

```ada
ODBC.Exec (...)
```

隐藏了：

```text
SQLAllocHandle
SQLExecDirectA
SQLFreeHandle
错误检查
SQLGetDiagRecA
```

因此上层程序只看到：

```ada
ODBC.Exec ("CREATE TABLE ...");
```

而不是：

```ada
SQLAllocHandle (...);
SQLExecDirectA (...);
if Result /= ...
SQLGetDiagRecA (...);
```

这就是封装的意义。

---

# 59. 每个函数的职责总表

| 函数                  | 作用                  |
| ------------------- | ------------------- |
| `SQLAllocHandle`    | 创建 ODBC Handle      |
| `SQLSetEnvAttr`     | 设置 ODBC Environment |
| `SQLDriverConnectA` | 建立数据库连接             |
| `SQLDisconnect`     | 断开数据库               |
| `SQLFreeHandle`     | 释放 Handle           |
| `SQLExecDirectA`    | 直接执行 SQL            |
| `SQLPrepareA`       | 准备参数化 SQL           |
| `SQLBindParameter`  | 绑定 SQL 参数           |
| `SQLExecute`        | 执行 Prepared SQL     |
| `SQLFetch`          | 获取 SELECT 下一行       |
| `SQLGetData`        | 获取当前行字段             |
| `SQLGetDiagRecA`    | 获取错误信息              |
| `SQLEndTran`        | COMMIT / ROLLBACK   |

---

# 60. 当前 Ada 封装函数总表

| Ada 函数                 | 用途          |
| ---------------------- | ----------- |
| `Initialize`           | 初始化 ODBC    |
| `Connect`              | 连接 Firebird |
| `Disconnect`           | 清理并断开       |
| `Exec`                 | 执行普通 SQL    |
| `Prepare`              | 准备参数 SQL    |
| `Bind_Integer_Address` | 绑定 INTEGER  |
| `Bind_String_Address`  | 绑定字符串       |
| `Execute`              | 执行参数 SQL    |
| `Fetch`                | 获取查询行       |
| `Get_String`           | 获取字符串列      |
| `Commit`               | 提交事务        |
| `Rollback`             | 回滚事务        |
| `Print_Diagnostics`    | 输出 ODBC 错误  |

---

# 61. 程序运行时的数据流

例如：

```ada
ID := 1;
Name := "Alice";
```

数据流：

```text
Ada variable
     │
     │ Address
     ▼
SQLBindParameter
     │
     ▼
ODBC Driver
     │
     ▼
Firebird
     │
     ▼
ADA_FB_DEMO
```

最终：

```text
+----+-------+
| ID | NAME  |
+----+-------+
| 1  | Alice |
+----+-------+
```

---

# 62. 编译过程

使用 Nushell：

```nu
gprbuild -P ada_odbc_firebird.gpr
```

GPRbuild：

```text
main.adb
   ↓
Ada compiler
   ↓
main.o

odbc.adb
   ↓
Ada compiler
   ↓
odbc.o

       ↓
     binder
       ↓
     linker
       ↓
   -lodbc32
       ↓
bin/main.exe
```

---

# 63. 运行

Nushell：

```nu
.\bin\main.exe
```

预期流程：

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

# 64. 数据库最终状态

执行完成后：

```sql
SELECT *
FROM ADA_FB_DEMO;
```

应该得到类似：

```text
ID    NAME
----  -----
1     Alice
```

---

# 65. 这个项目目前属于什么层次

目前我们实际上已经完成了一个：

> **最小可用 Ada ODBC 数据库访问层**

已经解决了几个最关键的问题：

```text
Ada ↔ C ABI
Ada ↔ ODBC
ODBC Environment
ODBC Connection
Firebird Driver
SQL 执行
参数绑定
事务
错误诊断
```

这已经比简单的：

```text
SQLExecDirect("...")
```

完整很多。

---

# 66. 下一阶段应该怎么扩展

如果继续做你前面那个 **Ada + Firebird 图书管理系统**，建议不要直接在 `main.adb` 里面写大量 ODBC API。

下一层应该变成：

```text
                    main.adb
                       │
                       ▼
              ┌─────────────────┐
              │   业务层         │
              │ books            │
              │ members          │
              │ loans            │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ database layer  │
              │ library_db      │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │     ODBC        │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ Firebird 5      │
              └─────────────────┘
```

最终项目可以形成：

```text
library_manager/
│
├── library_manager.gpr
│
├── main.adb
│
├── odbc.ads
├── odbc.adb
│
├── library_db.ads
├── library_db.adb
│
├── books.ads
├── books.adb
│
├── members.ads
├── members.adb
│
├── loans.ads
├── loans.adb
│
├── sql/
│   ├── 001_schema.sql
│   └── 002_seed.sql
│
└── obj/
```

---

# 67. 最终应该形成的分层

### 第一层：ODBC Binding

负责：

```text
SQLAllocHandle
SQLDriverConnect
SQLPrepare
SQLBindParameter
SQLExecute
SQLFetch
SQLGetData
SQLEndTran
```

文件：

```text
odbc.ads
odbc.adb
```

---

### 第二层：数据库访问层

例如：

```ada
Library_DB.Create_Book (...);
Library_DB.Find_Book (...);
Library_DB.Create_Member (...);
Library_DB.Borrow_Book (...);
Library_DB.Return_Book (...);
```

负责：

```text
SQL
参数
事务
数据库错误
```

---

### 第三层：业务层

例如：

```text
books
members
loans
```

处理：

```text
图书
会员
借阅
归还
```

---

### 第四层：UI

```text
main.adb
```

负责：

```text
菜单
用户输入
调用业务层
显示结果
```

这样 `main.adb` 就不会充斥大量 SQL。

---

# 68. 最重要的几个知识点

如果你正在通过这个项目学习 Ada，那么这个项目其实同时涉及了几个非常重要的 Ada 概念。

### ① `pragma Import`

```ada
pragma Import
  (Stdcall, SQLExecute, "SQLExecute");
```

解决：

```text
Ada → 外部 C/Windows API
```

---

### ② `System.Address`

```ada
ID'Address
```

解决：

```text
Ada 对象 → C 指针
```

---

### ③ `aliased`

```ada
ID : aliased SQLINTEGER;
```

解决：

```text
对象地址稳定地提供给外部代码
```

---

### ④ `access`

```ada
Output_Handle : access SQLHANDLE
```

解决：

```text
C 风格输出参数
```

---

### ⑤ `Interfaces.C`

```ada
Interfaces.C.int
Interfaces.C.short
Interfaces.C.long_long
```

解决：

```text
Ada 类型 ↔ C ABI 类型
```

---

### ⑥ `char_array`

```ada
Interfaces.C.Strings.char_array
```

解决：

```text
Ada String ↔ C 字符串
```

---

### ⑦ GPRbuild

解决：

```text
Ada 编译
对象文件
链接
ODBC DLL
```

---

# 69. 整个项目最值得记住的一张图

最后把整个项目压缩成一张图：

```text
                         Ada Application
                              │
                              ▼
                         main.adb
                              │
             ┌────────────────┴────────────────┐
             │                                 │
             ▼                                 ▼
       ODBC.Initialize                    ODBC.Connect
             │                                 │
             ▼                                 ▼
     SQLAllocHandle(ENV)              SQLAllocHandle(DBC)
             │                                 │
             ▼                                 ▼
      SQLSetEnvAttr                  SQLDriverConnectA
                                               │
                                               ▼
                                    Windows ODBC Manager
                                               │
                                               ▼
                                    Firebird ODBC Driver
                                               │
                                               ▼
                                         Firebird 5
                                               │
                                               ▼
                                           test.fdb


                  SQL 操作
                     │
          ┌──────────┼──────────┐
          │          │          │
          ▼          ▼          ▼
     SQLExecDirect SQLPrepare SQLExecute
                    │
                    ▼
             SQLBindParameter
                    │
                    ▼
                 参数值
                    │
                    ▼
                Firebird


                  SELECT
                     │
                     ▼
                 SQLExecute
                     │
                     ▼
                  SQLFetch
                     │
                     ▼
                 SQLGetData
                     │
                     ▼
                 Ada Result


                  事务
                     │
              ┌──────┴──────┐
              ▼             ▼
           COMMIT        ROLLBACK
              │             │
              ▼             ▼
         SQLEndTran      SQLEndTran


                  程序结束
                     │
                     ▼
               SQLDisconnect
                     │
                     ▼
            SQLFreeHandle(DBC)
                     │
                     ▼
            SQLFreeHandle(ENV)
```

**这就是刚才这个项目从 Ada 源代码一直到 Firebird 数据库的完整执行模型。**

其中最核心的思想可以记成一句话：

> **Ada 负责业务逻辑，`odbc.ads/adb` 负责把 Ada 调用转换成 ODBC 调用，Windows ODBC Manager 负责找到 Firebird Driver，Firebird Driver 再负责和 Firebird 5 通信。**

如果下一步继续做你前面那个**图书管理系统**，最合适的方向就是在这套 ODBC 底层之上继续实现 **`library_db.ads/adb → books → members → loans → 借书/还书事务`**，这样可以把刚才这个测试项目自然演变成一个完整的 Ada + Firebird 应用。
