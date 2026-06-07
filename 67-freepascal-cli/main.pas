// Free Pascal (Lazarus) CLI Victim -- Prime Sieve + Fibonacci
// Build: fpc -O2 main.pas -ofreepascal_cli.exe
program FreePascalCli;

{$mode objfpc}{$H+}

uses
  SysUtils;

function Fib(n: Integer): QWord;
var
  a, b, t: QWord;
  i: Integer;
begin
  if n <= 1 then
    Exit(QWord(n));
  a := 0;
  b := 1;
  for i := 2 to n do
  begin
    t := a + b;
    a := b;
    b := t;
  end;
  Result := b;
end;

var
  limit, count, largest, i, j: Integer;
  hash: QWord;
  buf: array of Boolean;
  fname, line: string;
  f: TextFile;
begin
  limit := 100;
  if ParamCount >= 1 then
    if TryStrToInt(ParamStr(1), limit) then
    begin
      if limit < 10 then
        limit := 10;
    end
    else
      limit := 100;

  WriteLn('Free Pascal CLI Victim -- Prime Sieve + Fibonacci');
  WriteLn('Limit: ', limit);
  WriteLn;
  WriteLn('Fibonacci(', limit, ') = ', Fib(limit));

  SetLength(buf, limit + 1);
  i := 2;
  while i * i <= limit do
  begin
    if not buf[i] then
    begin
      j := i * i;
      while j <= limit do
      begin
        buf[j] := True;
        Inc(j, i);
      end;
    end;
    Inc(i);
  end;

  count := 0;
  largest := 0;
  hash := 5381;
  for i := 2 to limit do
    if not buf[i] then
    begin
      Inc(count);
      largest := i;
      hash := (hash shl 5) + hash + QWord(i);
    end;

  WriteLn('Primes up to ', limit, ': ', count);
  if count > 0 then
    WriteLn('Largest prime: ', largest);

  fname := 'freepascal_cli_test.txt';
  try
    AssignFile(f, fname);
    Rewrite(f);
    WriteLn(f, 'Free Pascal CLI Victim -- ', count, ' primes up to ', limit);
    CloseFile(f);
    Reset(f);
    ReadLn(f, line);
    CloseFile(f);
    WriteLn('File I/O: ', line);
  except
  end;
  DeleteFile(fname);

  WriteLn('Checksum: 0x', IntToHex(hash, 16));
end.
