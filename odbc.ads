with System;
with Interfaces.C;

package ODBC is

   use Interfaces.C;

   ------------------------------------------------------------------
   -- ODBC basic types
   ------------------------------------------------------------------

   subtype SQLSMALLINT  is Interfaces.C.short;
   subtype SQLUSMALLINT is Interfaces.C.unsigned_short;

   subtype SQLINTEGER   is Interfaces.C.int;

   -- Windows 64-bit:
   -- SQLLEN / SQLULEN are 64-bit.
   subtype SQLLEN  is Interfaces.C.long_long;
   subtype SQLULEN is Interfaces.C.unsigned_long_long;

   subtype SQLRETURN is SQLSMALLINT;

   ------------------------------------------------------------------
   -- Handles
   ------------------------------------------------------------------

   subtype SQLHANDLE is System.Address;

   subtype SQLHENV  is SQLHANDLE;
   subtype SQLHDBC  is SQLHANDLE;
   subtype SQLHSTMT is SQLHANDLE;

   ------------------------------------------------------------------
   -- Return codes
   ------------------------------------------------------------------

   SQL_SUCCESS           : constant SQLRETURN := 0;
   SQL_SUCCESS_WITH_INFO : constant SQLRETURN := 1;
   SQL_ERROR             : constant SQLRETURN := -1;
   SQL_INVALID_HANDLE    : constant SQLRETURN := -2;
   SQL_NO_DATA           : constant SQLRETURN := 100;

   ------------------------------------------------------------------
   -- Handle types
   ------------------------------------------------------------------

   SQL_HANDLE_ENV  : constant SQLSMALLINT := 1;
   SQL_HANDLE_DBC  : constant SQLSMALLINT := 2;
   SQL_HANDLE_STMT : constant SQLSMALLINT := 3;

   ------------------------------------------------------------------
   -- Environment
   ------------------------------------------------------------------

   SQL_ATTR_ODBC_VERSION : constant SQLINTEGER := 200;

   SQL_OV_ODBC3 : constant SQLINTEGER := 3;

   ------------------------------------------------------------------
   -- Driver connection
   ------------------------------------------------------------------

   SQL_DRIVER_NOPROMPT : constant SQLUSMALLINT := 0;

   ------------------------------------------------------------------
   -- C data types
   ------------------------------------------------------------------

   SQL_C_CHAR : constant SQLSMALLINT := 1;
   SQL_C_LONG : constant SQLSMALLINT := 4;

   ------------------------------------------------------------------
   -- SQL data types
   ------------------------------------------------------------------

   SQL_INTEGER : constant SQLSMALLINT := 4;
   SQL_VARCHAR : constant SQLSMALLINT := 12;

   ------------------------------------------------------------------
   -- Parameter types
   ------------------------------------------------------------------

   SQL_PARAM_INPUT : constant SQLSMALLINT := 1;

   ------------------------------------------------------------------
   -- Transaction
   ------------------------------------------------------------------

   SQL_COMMIT   : constant SQLUSMALLINT := 0;
   SQL_ROLLBACK : constant SQLUSMALLINT := 1;

   ------------------------------------------------------------------
   -- ODBC API
   ------------------------------------------------------------------

   function SQLAllocHandle
     (Handle_Type   : SQLSMALLINT;
      Input_Handle  : SQLHANDLE;
      Output_Handle : access SQLHANDLE)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLAllocHandle,
      "SQLAllocHandle");

   ------------------------------------------------------------------

   function SQLSetEnvAttr
     (Environment_Handle : SQLHENV;
      Attribute          : SQLINTEGER;
      Value              : System.Address;
      String_Length      : SQLINTEGER)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLSetEnvAttr,
      "SQLSetEnvAttr");

   ------------------------------------------------------------------

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

   pragma Import
     (Stdcall,
      SQLDriverConnectA,
      "SQLDriverConnectA");

   ------------------------------------------------------------------

   function SQLDisconnect
     (Connection_Handle : SQLHDBC)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLDisconnect,
      "SQLDisconnect");

   ------------------------------------------------------------------

   function SQLFreeHandle
     (Handle_Type : SQLSMALLINT;
      Handle      : SQLHANDLE)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLFreeHandle,
      "SQLFreeHandle");

   ------------------------------------------------------------------

   function SQLExecDirectA
     (Statement_Handle : SQLHSTMT;
      Statement_Text   : System.Address;
      Text_Length      : SQLINTEGER)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLExecDirectA,
      "SQLExecDirectA");

   ------------------------------------------------------------------

   function SQLPrepareA
     (Statement_Handle : SQLHSTMT;
      Statement_Text   : System.Address;
      Text_Length      : SQLINTEGER)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLPrepareA,
      "SQLPrepareA");

   ------------------------------------------------------------------

   function SQLBindParameter
     (Statement_Handle : SQLHSTMT;
      Parameter_Number : SQLUSMALLINT;
      Input_Output     : SQLSMALLINT;
      Value_Type       : SQLSMALLINT;
      Parameter_Type   : SQLSMALLINT;
      Column_Size      : SQLULEN;
      Decimal_Digits   : SQLSMALLINT;
      Parameter_Value  : System.Address;
      Buffer_Length    : SQLLEN;
      StrLen_Or_Ind    : System.Address)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLBindParameter,
      "SQLBindParameter");

   ------------------------------------------------------------------

   function SQLExecute
     (Statement_Handle : SQLHSTMT)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLExecute,
      "SQLExecute");

   ------------------------------------------------------------------

   function SQLFetch
     (Statement_Handle : SQLHSTMT)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLFetch,
      "SQLFetch");

   ------------------------------------------------------------------

   function SQLGetData
     (Statement_Handle : SQLHSTMT;
      Column_Number    : SQLUSMALLINT;
      Target_Type      : SQLSMALLINT;
      Target_Value     : System.Address;
      Buffer_Length     : SQLLEN;
      StrLen_Or_Ind    : System.Address)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLGetData,
      "SQLGetData");

   ------------------------------------------------------------------

   function SQLGetDiagRecA
     (Handle_Type   : SQLSMALLINT;
      Handle        : SQLHANDLE;
      Record_Number : SQLSMALLINT;
      SQL_State     : System.Address;
      Native_Error  : access SQLINTEGER;
      Message_Text  : System.Address;
      Buffer_Length : SQLSMALLINT;
      Text_Length   : access SQLSMALLINT)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLGetDiagRecA,
      "SQLGetDiagRecA");

   ------------------------------------------------------------------

   function SQLEndTran
     (Handle_Type : SQLSMALLINT;
      Handle      : SQLHANDLE;
      Completion  : SQLUSMALLINT)
      return SQLRETURN;

   pragma Import
     (Stdcall,
      SQLEndTran,
      "SQLEndTran");

   ------------------------------------------------------------------
   -- High level wrapper
   ------------------------------------------------------------------

   procedure Initialize;

   procedure Connect
     (Connection_String : String);

   procedure Disconnect;

   procedure Exec
     (SQL : String);

   procedure Prepare
     (SQL : String);

   procedure Bind_Integer_Address
     (Position          : Positive;
      Value_Address     : System.Address;
      Indicator_Address : System.Address);

   procedure Bind_String_Address
     (Position          : Positive;
      Value_Address     : System.Address;
      Buffer_Length     : SQLLEN;
      Column_Size       : SQLULEN;
      Indicator_Address : System.Address);

   procedure Execute;

   procedure Fetch;

   function Get_String
     (Column : Positive) return String;

   procedure Commit;

   procedure Rollback;

   procedure Print_Diagnostics
     (Handle_Type : SQLSMALLINT;
      Handle      : SQLHANDLE);

end ODBC;