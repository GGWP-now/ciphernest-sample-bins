--  Ada CLI Victim -- Prime Sieve + Fibonacci
--  Build: gnatmake -O2 main.adb -o ada_cli.exe
with Ada.Text_IO;       use Ada.Text_IO;
with Ada.Command_Line;  use Ada.Command_Line;
with Interfaces;        use Interfaces;

procedure Main is

   function Fib (N : Integer) return Unsigned_64 is
      A : Unsigned_64 := 0;
      B : Unsigned_64 := 1;
      T : Unsigned_64;
   begin
      if N <= 1 then
         return Unsigned_64 (N);
      end if;
      for I in 2 .. N loop
         T := A + B;
         A := B;
         B := T;
      end loop;
      return B;
   end Fib;

   function To_Hex16 (V : Unsigned_64) return String is
      Digits_Set : constant String := "0123456789ABCDEF";
      Result     : String (1 .. 16);
      Acc        : Unsigned_64 := V;
   begin
      for K in reverse Result'Range loop
         Result (K) := Digits_Set (Integer (Acc and 16#F#) + 1);
         Acc := Shift_Right (Acc, 4);
      end loop;
      return Result;
   end To_Hex16;

   Limit   : Integer := 100;
   Count   : Integer := 0;
   Largest : Integer := 0;
   Hash    : Unsigned_64 := 5381;
begin
   if Argument_Count >= 1 then
      begin
         Limit := Integer'Value (Argument (1));
         if Limit < 10 then
            Limit := 10;
         end if;
      exception
         when others => Limit := 100;
      end;
   end if;

   Put_Line ("Ada CLI Victim -- Prime Sieve + Fibonacci");
   Put_Line ("Limit:" & Integer'Image (Limit));
   New_Line;
   Put_Line ("Fibonacci(" & Integer'Image (Limit) & " ) =" &
             Unsigned_64'Image (Fib (Limit)));

   declare
      Buf : array (0 .. Limit) of Boolean := (others => False);
      I   : Integer := 2;
      J   : Integer;
   begin
      while I * I <= Limit loop
         if not Buf (I) then
            J := I * I;
            while J <= Limit loop
               Buf (J) := True;
               J := J + I;
            end loop;
         end if;
         I := I + 1;
      end loop;

      for N in 2 .. Limit loop
         if not Buf (N) then
            Count := Count + 1;
            Largest := N;
            Hash := Shift_Left (Hash, 5) + Hash + Unsigned_64 (N);
         end if;
      end loop;
   end;

   Put_Line ("Primes up to" & Integer'Image (Limit) & ":" &
             Integer'Image (Count));
   if Count > 0 then
      Put_Line ("Largest prime:" & Integer'Image (Largest));
   end if;

   declare
      Fname : constant String := "ada_cli_test.txt";
      F     : File_Type;
      Line  : String (1 .. 256);
      Last  : Natural := 0;
   begin
      Create (F, Out_File, Fname);
      Put_Line (F, "Ada CLI Victim --" & Integer'Image (Count) &
                " primes up to" & Integer'Image (Limit));
      Close (F);
      Open (F, In_File, Fname);
      Get_Line (F, Line, Last);
      Close (F);
      Put_Line ("File I/O: " & Line (1 .. Last));
   exception
      when others => null;
   end;

   Put_Line ("Checksum: 0x" & To_Hex16 (Hash));
end Main;
