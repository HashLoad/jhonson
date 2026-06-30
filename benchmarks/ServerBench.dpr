program ServerBench;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  System.JSON;

begin
  try
    THorse.Use(Jhonson());

    THorse.Post('/json_object',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        LObj: TJSONObject;
      begin
        LObj := Req.Body<TJSONObject>;
        Res.Send(LObj.ToJSON);
      end);

    THorse.Listen(9091);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
