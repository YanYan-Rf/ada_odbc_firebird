with Ada.Text_IO;
with Ada.Exceptions;
with Interfaces.C;
with Interfaces.C.Strings;
with ODBC;

procedure Main is

   use Ada.Text_IO;
   use Interfaces.C;
   use Interfaces.C.Strings;

   ------------------------------------------------------------------
   -- Firebird connection
   ------------------------------------------------------------------

  Connection_String : constant String :=
  "DRIVER=Firebird ODBC Driver;"
  & "DBNAME=localhost:F:\proj-2025\ada\data\test.fdb;"
  & "UID=SYSDBA;"
  & "PWD=123456;";


   ------------------------------------------------------------------
   -- Parameter buffers
   --
   -- IMPORTANT:
   -- These variables must remain alive until SQLExecute.
   ------------------------------------------------------------------

   ID : aliased ODBC.SQLINTEGER := 1;

   Name : aliased char_array :=
     To_C ("Alice");


   ID_Indicator : aliased ODBC.SQLLEN := 4;

   Name_Indicator : aliased ODBC.SQLLEN :=
     ODBC.SQLLEN (Name'Length - 1);


   Connected : Boolean := False;


begin

   Put_Line
     ("========================================");

   Put_Line
     (" Ada + ODBC + Firebird 5");

   Put_Line
     ("========================================");

   New_Line;


   ------------------------------------------------------------------
   -- 1. Initialize ODBC
   ------------------------------------------------------------------

   Put_Line
     ("[1] Initializing ODBC...");

   ODBC.Initialize;


   ------------------------------------------------------------------
   -- 2. Connect
   ------------------------------------------------------------------

   New_Line;

   Put_Line
     ("[2] Connecting to Firebird...");

   ODBC.Connect
     (Connection_String);

   Connected := True;


   ------------------------------------------------------------------
   -- 3. Create test table
   ------------------------------------------------------------------

   New_Line;

   Put_Line
     ("[3] Creating test table...");


   -- The table may already exist.
   -- Ignore DROP errors.

   begin

      ODBC.Exec
        ("DROP TABLE ADA_FB_DEMO");

   exception

      when others =>
         null;

   end;


   ODBC.Exec
     ("CREATE TABLE ADA_FB_DEMO "
      & "(ID INTEGER NOT NULL PRIMARY KEY, "
      & "NAME VARCHAR(100))");


   Put_Line
     ("Table created");


   ------------------------------------------------------------------
   -- 4. Parameterized INSERT
   ------------------------------------------------------------------

   New_Line;

   Put_Line
     ("[4] INSERT using parameters...");


   ODBC.Prepare
     ("INSERT INTO ADA_FB_DEMO (ID, NAME) "
      & "VALUES (?, ?)");


   ---------------------------------------------------------------
   -- Parameter 1
   ---------------------------------------------------------------

   ODBC.Bind_Integer_Address
     (1,
      ID'Address,
      ID_Indicator'Address);


   ---------------------------------------------------------------
   -- Parameter 2
   ---------------------------------------------------------------

   ODBC.Bind_String_Address
     (2,
      Name'Address,
      ODBC.SQLLEN (Name'Length),
      ODBC.SQLULEN (Name'Length - 1),
      Name_Indicator'Address);


   ---------------------------------------------------------------
   -- Execute
   ---------------------------------------------------------------

   ODBC.Execute;


   Put_Line
     ("INSERT OK");


   ------------------------------------------------------------------
   -- 5. COMMIT
   ------------------------------------------------------------------

   New_Line;

   Put_Line
     ("[5] COMMIT...");

   ODBC.Commit;

   Put_Line
     ("COMMIT OK");


   ------------------------------------------------------------------
   -- 6. Done
   ------------------------------------------------------------------

   New_Line;

   Put_Line
     ("========================================");

   Put_Line
     ("Done");

   Put_Line
     ("========================================");


   ------------------------------------------------------------------
   -- Disconnect
   ------------------------------------------------------------------

   ODBC.Disconnect;


exception

   when E : others =>

      Put_Line ("");
      Put_Line ("*** ERROR ***");

      Put_Line
        (Ada.Exceptions.Exception_Information (E));


      ---------------------------------------------------------------
      -- Only rollback if connection was successfully established.
      ---------------------------------------------------------------

      if Connected then

         begin

            ODBC.Rollback;

         exception

            when others =>
               null;

         end;

      end if;


      ---------------------------------------------------------------
      -- Disconnect
      ---------------------------------------------------------------

      begin

         ODBC.Disconnect;

      exception

         when others =>
            null;

      end;

end Main;