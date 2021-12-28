# jhonson
<b>Jhonson</b> is a official middleware for working with JSON in APIs developed with the <a href="https://github.com/HashLoad/horse">Horse</a> framework.
<br>We created a channel on Telegram for questions and support:<br><br>
<a href="https://t.me/hashload">
  <img src="https://img.shields.io/badge/telegram-join%20channel-7289DA?style=flat-square">
</a>

## ⚙️ Installation
Installation is done using the [`boss install`](https://github.com/HashLoad/boss) command:
``` sh
boss install jhonson
```
If you choose to install manually, simply add the following folders to your project, in *Project > Options > Resource Compiler > Directories and Conditionals > Include file search path*
```
../jhonson/src
```

## ✔️ Compatibility
This middleware is compatible with projects developed in:
- [X] Delphi
- [X] Lazarus

## ⚡️ Quickstart Delphi
```delphi
uses 
  Horse, 
  Horse.Jhonson, // It's necessary to use the unit
  System.JSON;

begin
  // It's necessary to add the middleware in the Horse:
  THorse.Use(Jhonson());
  
  // You can specify the charset when adding middleware to the Horse:
  // THorse.Use(Jhonson('UTF-8')); 

  THorse.Post('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LBody: TJSONObject;
    begin
      // Req.Body gives access to the content of the request in string format.
      // Using jhonson middleware, we can get the content of the request in JSON format.
      
      LBody := Req.Body<TJSONObject>;
      Res.Send<TJSONObject>(LBody);
    end);

  THorse.Listen(9000);
end;
```

## ⚡️ Quickstart Lazarus
```delphi
{$MODE DELPHI}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Horse, 
  Horse.Jhonson, // It's necessary to use the unit 
  fpjson, 
  SysUtils;

procedure PostPing(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  LBody: TJSONObject;
begin
  // Req.Body gives access to the content of the request in string format.
  // Using jhonson middleware, we can get the content of the request in JSON format.
  LBody := Req.Body<TJSONObject>;
  Res.Send<TJSONObject>(LBody);
end;

begin
  // It's necessary to add the middleware in the Horse:
  THorse.Use(Jhonson);
  
  // You can specify the charset when adding middleware to the Horse:
  // THorse.Use(Jhonson('UTF-8')); 

  THorse.Post('/ping', PostPing);

  THorse.Listen(9000);
end.
```

## ⚠️ License
`Jhonson` is free and open-source middleware licensed under the [MIT License](https://github.com/HashLoad/jhonson/blob/master/LICENSE). 
