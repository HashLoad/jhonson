program Samples;

{$APPTYPE CONSOLE}
{$R *.res}

uses Horse, Horse.Jhonson, System.JSON;

begin
  THorse.Use(Jhonson);

  THorse.Post('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LBody: TJSONObject;
    begin
      LBody := Req.Body<TJSONObject>;
      Res.Send<TJSONObject>(LBody);
    end);

  THorse.Listen(9000);
end.
