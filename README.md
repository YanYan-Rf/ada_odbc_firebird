# Ada + GNAT + Firebird 5 + ODBC

## Prerequisites

- Windows 64-bit
- 64-bit GNAT/GPRbuild
- Firebird 5.x
- 64-bit Firebird ODBC Driver 3.x
- The driver name used by this project is `Firebird ODBC Driver`.
- Windows ODBC Driver Manager (`odbc32.dll`) is supplied by Windows.

The Firebird ODBC 3.x driver is intended for Firebird 3.x and later, including Firebird 5.x.

## 1. Create the database

For example, create:

    F:\proj-2025\ada\data\ada_odbc.fdb

The exact creation command depends on your Firebird installation. You can also use an existing Firebird database.

## 2. Verify the ODBC driver

Open:

    ODBC Data Sources (64-bit)

and verify that `Firebird ODBC Driver` is installed.

## 3. Edit the connection string

Open `main.adb` and change:

    DBNAME=localhost:F:\proj-2025\ada\data\ada_odbc.fdb;
    UID=SYSDBA;
    PWD=123456;

to match your database.

## 4. Build

From the project directory:

    gprbuild -P ada_odbc_firebird.gpr

## 5. Run

    bin\main.exe

Expected output is similar to:

    Ada + ODBC + Firebird 5 demo
    Connecting...
    Connected.
    INSERT + COMMIT OK.
    Rows:
      ID=1  NAME=Alice
    UPDATE + ROLLBACK OK.
    After rollback: ID=1 NAME=Alice
    Disconnected.

## Important

This first demo intentionally binds both values as `SQL_C_CHAR`/`SQL_VARCHAR`.
The Firebird server/driver converts the first value to INTEGER.

The next production-oriented version should bind:
- INTEGER as SQL_C_SLONG / SQL_INTEGER
- DECIMAL/DECFLOAT using an appropriate representation
- DATE/TIMESTAMP using ODBC date/time structures
- NULL using SQL_NULL_DATA
- large text with SQL_LONGVARCHAR

It should also expose diagnostic records through SQLGetDiagRec instead of only returning an ODBC return code.
