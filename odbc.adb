with System;
with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Text_IO;

package body ODBC is

   use Interfaces.C;
   use Interfaces.C.Strings;
   use Ada.Text_IO;

   ------------------------------------------------------------------
   -- ODBC handles
   ------------------------------------------------------------------

   Environment : aliased SQLHENV  := System.Null_Address;
   Connection  : aliased SQLHDBC  := System.Null_Address;
   Statement   : aliased SQLHSTMT := System.Null_Address;

   ------------------------------------------------------------------
   -- Diagnostics
   ------------------------------------------------------------------

   procedure Print_Diagnostics
     (Handle_Type : SQLSMALLINT;
      Handle      : SQLHANDLE)
   is

      State : aliased char_array (0 .. 5) :=
        (others => nul);

      Message : aliased char_array (0 .. 1023) :=
        (others => nul);

      Native_Error : aliased SQLINTEGER := 0;

      Text_Length : aliased SQLSMALLINT := 0;

      Record_Number : SQLSMALLINT := 1;

      Result : SQLRETURN;

   begin

      loop

         Result :=
           SQLGetDiagRecA
             (Handle_Type,
              Handle,
              Record_Number,
              State'Address,
              Native_Error'Access,
              Message'Address,
              SQLSMALLINT (Message'Length),
              Text_Length'Access);

         exit when Result = SQL_NO_DATA;

         exit when
           Result /= SQL_SUCCESS
           and then
           Result /= SQL_SUCCESS_WITH_INFO;

         Put_Line
           ("  SQLSTATE     : " &
            To_Ada (State));

         Put_Line
           ("  Native Error : " &
            SQLINTEGER'Image (Native_Error));

         Put_Line
           ("  Message      : " &
            To_Ada (Message));

         Record_Number := Record_Number + 1;

      end loop;

   end Print_Diagnostics;


   ------------------------------------------------------------------
   -- Initialize ODBC
   ------------------------------------------------------------------

   procedure Initialize is

      Result : SQLRETURN;

   begin

      Result :=
        SQLAllocHandle
          (SQL_HANDLE_ENV,
           System.Null_Address,
           Environment'Access);

      if Result /= SQL_SUCCESS then

         Put_Line
           ("ODBC ERROR: SQLAllocHandle ENV return =" &
            SQLRETURN'Image (Result));

         raise Program_Error with
           "ODBC operation failed: SQLAllocHandle";

      end if;


      --
      -- IMPORTANT:
      --
      -- SQL_ATTR_ODBC_VERSION expects the numeric value
      -- SQL_OV_ODBC3 encoded as a pointer.
      --
      -- SQL_OV_ODBC3 = 3
      --
      -- GNAT provides System'To_Address for this conversion.
      --

      Result :=
        SQLSetEnvAttr
          (Environment,
           SQL_ATTR_ODBC_VERSION,
           System'To_Address (SQL_OV_ODBC3),
           0);

      if Result /= SQL_SUCCESS then

         Put_Line
           ("ODBC ERROR: SQLSetEnvAttr return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_ENV,
            Environment);

         raise Program_Error with
           "ODBC operation failed: SQLSetEnvAttr";

      end if;

      Put_Line ("OK");

   end Initialize;


   ------------------------------------------------------------------
   -- Connect
   ------------------------------------------------------------------

   procedure Connect
     (Connection_String : String)
   is

      Conn_C : aliased char_array :=
        To_C (Connection_String);

      Out_C : aliased char_array (0 .. 1023) :=
        (others => nul);

      Out_Length : aliased SQLSMALLINT := 0;

      Result : SQLRETURN;

   begin

      ---------------------------------------------------------------
      -- Allocate connection handle
      ---------------------------------------------------------------

      Result :=
        SQLAllocHandle
          (SQL_HANDLE_DBC,
           Environment,
           Connection'Access);

      if Result /= SQL_SUCCESS then

         Put_Line
           ("ODBC ERROR: SQLAllocHandle DBC return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_ENV,
            Environment);

         raise Program_Error with
           "ODBC operation failed: SQLAllocHandle DBC";

      end if;


      ---------------------------------------------------------------
      -- Connect
      ---------------------------------------------------------------

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

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
      then

         Put_Line
           ("ODBC ERROR: SQLDriverConnectA return =" &
            SQLRETURN'Image (Result));

         Put_Line ("ODBC diagnostics:");

         Print_Diagnostics
           (SQL_HANDLE_DBC,
            Connection);

         raise Program_Error with
           "ODBC operation failed: SQLDriverConnectA";

      end if;


      if Result = SQL_SUCCESS_WITH_INFO then

         Put_Line
           ("ODBC: SQLDriverConnect returned SUCCESS_WITH_INFO");

         Print_Diagnostics
           (SQL_HANDLE_DBC,
            Connection);

      end if;


      Put_Line ("Connected");

   end Connect;


   ------------------------------------------------------------------
   -- Disconnect
   ------------------------------------------------------------------

   procedure Disconnect is

      Result : SQLRETURN;

   begin

      ---------------------------------------------------------------
      -- Free statement
      ---------------------------------------------------------------

      if not System."=" (Statement, System.Null_Address) then

         Result :=
           SQLFreeHandle
             (SQL_HANDLE_STMT,
              Statement);

         Statement := System.Null_Address;

      end if;


      ---------------------------------------------------------------
      -- Disconnect database
      ---------------------------------------------------------------

      if not System."=" (Connection, System.Null_Address) then

         Result :=
           SQLDisconnect
             (Connection);

         Connection := System.Null_Address;

      end if;


      ---------------------------------------------------------------
      -- Free connection handle
      ---------------------------------------------------------------

      if not System."=" (Connection, System.Null_Address) then

         Result :=
           SQLFreeHandle
             (SQL_HANDLE_DBC,
              Connection);

         Connection := System.Null_Address;

      end if;


      ---------------------------------------------------------------
      -- Free environment
      ---------------------------------------------------------------

      if not System."=" (Environment, System.Null_Address) then

         Result :=
           SQLFreeHandle
             (SQL_HANDLE_ENV,
              Environment);

         Environment := System.Null_Address;

      end if;

   end Disconnect;


   ------------------------------------------------------------------
   -- Execute SQL directly
   ------------------------------------------------------------------

   procedure Exec
     (SQL : String)
   is

      SQL_C : aliased char_array :=
        To_C (SQL);

      Result : SQLRETURN;

   begin

      ---------------------------------------------------------------
      -- Allocate statement
      ---------------------------------------------------------------

      if System."=" (Statement, System.Null_Address) then

         Result :=
           SQLAllocHandle
             (SQL_HANDLE_STMT,
              Connection,
              Statement'Access);

         if Result /= SQL_SUCCESS then

            Put_Line
              ("ODBC ERROR: SQLAllocHandle STMT return =" &
               SQLRETURN'Image (Result));

            Print_Diagnostics
              (SQL_HANDLE_DBC,
               Connection);

            raise Program_Error with
              "ODBC operation failed: SQLAllocHandle STMT";

         end if;

      end if;


      ---------------------------------------------------------------
      -- Execute SQL
      ---------------------------------------------------------------

      Result :=
        SQLExecDirectA
          (Statement,
           SQL_C'Address,
           SQLINTEGER (SQL_C'Length - 1));

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
      then

         Put_Line
           ("ODBC ERROR: SQLExecDirectA return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_STMT,
            Statement);

         raise Program_Error with
           "ODBC operation failed: SQLExecDirectA";

      end if;

   end Exec;


   ------------------------------------------------------------------
   -- Prepare
   ------------------------------------------------------------------

   procedure Prepare
     (SQL : String)
   is

      SQL_C : aliased char_array :=
        To_C (SQL);

      Result : SQLRETURN;

   begin

      ---------------------------------------------------------------
      -- Free previous statement
      ---------------------------------------------------------------

      if not System."=" (Statement, System.Null_Address) then

         Result :=
           SQLFreeHandle
             (SQL_HANDLE_STMT,
              Statement);

         Statement := System.Null_Address;

      end if;


      ---------------------------------------------------------------
      -- Allocate statement
      ---------------------------------------------------------------

      Result :=
        SQLAllocHandle
          (SQL_HANDLE_STMT,
           Connection,
           Statement'Access);

      if Result /= SQL_SUCCESS then

         Put_Line
           ("ODBC ERROR: SQLAllocHandle STMT return =" &
            SQLRETURN'Image (Result));

         raise Program_Error with
           "ODBC operation failed: SQLAllocHandle STMT";

      end if;


      ---------------------------------------------------------------
      -- Prepare SQL
      ---------------------------------------------------------------

      Result :=
        SQLPrepareA
          (Statement,
           SQL_C'Address,
           SQLINTEGER (SQL_C'Length - 1));

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
      then

         Put_Line
           ("ODBC ERROR: SQLPrepareA return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_STMT,
            Statement);

         raise Program_Error with
           "ODBC operation failed: SQLPrepareA";

      end if;

   end Prepare;


   ------------------------------------------------------------------
   -- Bind Integer
   ------------------------------------------------------------------

   procedure Bind_Integer_Address
     (Position          : Positive;
      Value_Address     : System.Address;
      Indicator_Address : System.Address)
   is

      Result : SQLRETURN;

   begin

      Result :=
        SQLBindParameter
          (Statement,
           SQLUSMALLINT (Position),
           SQL_PARAM_INPUT,
           SQL_C_LONG,
           SQL_INTEGER,
           10,
           0,
           Value_Address,
           SQLLEN (4),
           Indicator_Address);

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
      then

         Put_Line
           ("ODBC ERROR: SQLBindParameter INTEGER return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_STMT,
            Statement);

         raise Program_Error with
           "ODBC operation failed: SQLBindParameter INTEGER";

      end if;

   end Bind_Integer_Address;


   ------------------------------------------------------------------
   -- Bind String
   ------------------------------------------------------------------

   procedure Bind_String_Address
     (Position          : Positive;
      Value_Address     : System.Address;
      Buffer_Length     : SQLLEN;
      Column_Size       : SQLULEN;
      Indicator_Address : System.Address)
   is

      Result : SQLRETURN;

   begin

      Result :=
        SQLBindParameter
          (Statement,
           SQLUSMALLINT (Position),
           SQL_PARAM_INPUT,
           SQL_C_CHAR,
           SQL_VARCHAR,
           Column_Size,
           0,
           Value_Address,
           Buffer_Length,
           Indicator_Address);

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
      then

         Put_Line
           ("ODBC ERROR: SQLBindParameter VARCHAR return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_STMT,
            Statement);

         raise Program_Error with
           "ODBC operation failed: SQLBindParameter VARCHAR";

      end if;

   end Bind_String_Address;


   ------------------------------------------------------------------
   -- Execute prepared statement
   ------------------------------------------------------------------

   procedure Execute is

      Result : SQLRETURN;

   begin

      Result :=
        SQLExecute
          (Statement);

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
      then

         Put_Line
           ("ODBC ERROR: SQLExecute return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_STMT,
            Statement);

         raise Program_Error with
           "ODBC operation failed: SQLExecute";

      end if;

   end Execute;


   ------------------------------------------------------------------
   -- Fetch
   ------------------------------------------------------------------

   procedure Fetch is

      Result : SQLRETURN;

   begin

      Result :=
        SQLFetch
          (Statement);

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
        and then
           Result /= SQL_NO_DATA
      then

         Put_Line
           ("ODBC ERROR: SQLFetch return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_STMT,
            Statement);

         raise Program_Error with
           "ODBC operation failed: SQLFetch";

      end if;

   end Fetch;


   ------------------------------------------------------------------
   -- Get string column
   ------------------------------------------------------------------

   function Get_String
     (Column : Positive) return String
   is

      Buffer : aliased char_array (0 .. 1023) :=
        (others => nul);

      Length : aliased SQLLEN := 0;

      Result : SQLRETURN;

      Last : size_t;

   begin

      Result :=
        SQLGetData
          (Statement,
           SQLUSMALLINT (Column),
           SQL_C_CHAR,
           Buffer'Address,
           SQLLEN (Buffer'Length),
           Length'Address);

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
      then

         Put_Line
           ("ODBC ERROR: SQLGetData return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_STMT,
            Statement);

         raise Program_Error with
           "ODBC operation failed: SQLGetData";

      end if;


      if Length <= 0 then
         return "";
      end if;


      Last := size_t (Length - 1);

      return
        To_Ada
          (Buffer
             (Buffer'First ..
              Buffer'First + Last));

   end Get_String;


   ------------------------------------------------------------------
   -- COMMIT
   ------------------------------------------------------------------

   procedure Commit is

      Result : SQLRETURN;

   begin

      Result :=
        SQLEndTran
          (SQL_HANDLE_DBC,
           Connection,
           SQL_COMMIT);

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
      then

         Put_Line
           ("ODBC ERROR: SQLEndTran COMMIT return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_DBC,
            Connection);

         raise Program_Error with
           "ODBC COMMIT failed";

      end if;

   end Commit;


   ------------------------------------------------------------------
   -- ROLLBACK
   ------------------------------------------------------------------

   procedure Rollback is

      Result : SQLRETURN;

   begin

      if System."=" (Connection, System.Null_Address) then
         return;
      end if;

      Result :=
        SQLEndTran
          (SQL_HANDLE_DBC,
           Connection,
           SQL_ROLLBACK);

      if Result /= SQL_SUCCESS
        and then
           Result /= SQL_SUCCESS_WITH_INFO
      then

         Put_Line
           ("ODBC ERROR: SQLEndTran ROLLBACK return =" &
            SQLRETURN'Image (Result));

         Print_Diagnostics
           (SQL_HANDLE_DBC,
            Connection);

      end if;

   end Rollback;

end ODBC;