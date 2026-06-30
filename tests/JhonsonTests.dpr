program JhonsonTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TestFramework,
  TextTestRunner,
  Test.Horse.Jhonson in 'Test.Horse.Jhonson.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TextTestRunner.RunRegisteredTests;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
