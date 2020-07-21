unit Horse.Jhonson;

interface

uses
  Horse, System.Classes, System.JSON, Web.HTTPApp, System.SysUtils;

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

  if (LWebRequest.MethodType in [mtPost, mtPut]) and
    (LWebRequest.ContentType = 'application/json') then
  begin
    LJSON := TJSONObject.ParseJSONValue(Req.Body);
    THorseHackRequest(Req).SetBody(LJSON);
  end;

  Next;

  LWebResponse := THorseHackResponse(Res).GetWebResponse;
  LContent := THorseHackResponse(Res).GetContent;

  if LContent.InheritsFrom(TJSONValue) then
  begin
    if Assigned(LContent) then
	begin
      LWebResponse.Content := TJSONValue(LContent).ToJSON
	end  
    else 
	begin
      LWebResponse.StatusCode := THttpStatus.NoContent.ToInteger;
	end;  
    LWebResponse.ContentType := 'application/json';
  end;
end;

end.
