# jhonson
Middleware for parse JSON in HORSE

Sample Horse Server
```delphi
uses
  Horse, Horse.Jhonson, System.JSON;

var
  App: THorse;

begin
  App := THorse.Create(9000);

  App.Use(Jhonson);

  App.Post('ping',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LBody: TJSONObject;
    begin
      LBody := Req.Body<TJSONObject>;
      Res.Send<TJSONObject>(LBody);
    end);

  App.Start;
end.
```
