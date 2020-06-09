unit Horse.Jhonson;

interface

uses Horse, System.Classes, System.JSON, Web.HTTPApp, System.SysUtils;

procedure Jhonson(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

procedure Jhonson(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LWebRequest: TWebRequest;
  LWebResponse: TWebResponse;
  LContent: TObject;
  LJSON: TJSONValue;
begin
  LWebRequest := THorseHackRequest(Req).GetWebRequest;

  if (LWebRequest.MethodType in [mtPost, mtPut]) and (LWebRequest.ContentType = 'application/json') then
  begin
    LJSON := TJSONObject.ParseJSONValue(Req.Body);
    THorseHackRequest(Req).SetBody(LJSON);
  end;

  try
    try
      Next;
    except
      raise;
    end;
  finally
    LWebResponse := THorseHackResponse(Res).GetWebResponse;
    LContent := THorseHackResponse(Res).GetContent;

    if Assigned(LContent) and LContent.InheritsFrom(TJSONValue) then
    begin
      LWebResponse.Content := TJSONValue(LContent).ToJSON;
      LWebResponse.ContentType := 'application/json';
    end;
  end;
end;

end.
