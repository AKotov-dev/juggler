unit ping_trd;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, Controls, SysUtils, Process, Graphics;

type
  CheckPing = class(TThread)
  private

    { Private declarations }
  protected
  var
    PingStr: TStringList;

    procedure Execute; override;
    procedure ShowStatus;

  end;

implementation

uses unit1;

{ TRD }

procedure CheckPing.Execute;
var
  PingProcess: TProcess;
begin
  FreeOnTerminate := True; //Уничтожать по завершении

  while not Terminated do
    try
      PingStr := TStringList.Create;
      PingProcess := TProcess.Create(nil);

      PingProcess.Executable := 'bash';
      PingProcess.Parameters.Add('-c');
      PingProcess.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];

      PingProcess.Parameters.Add('fping -e google.com');
      PingProcess.Execute;

      PingStr.LoadFromStream(PingProcess.Output);
      Synchronize(@ShowStatus);

      Sleep(1000);
    finally
      PingStr.Free;
      PingProcess.Free;
    end;
end;

procedure CheckPing.ShowStatus;
var
  i: integer;
begin
  with MainForm do
  begin
    //Вывод построчно
    for i := 0 to PingStr.Count - 1 do
      if Pos('unreachable', PingStr[i]) <> 0 then
        PingMemo.Append(PingStr[i] + ' ' + STryGoToSite)
      else
        PingMemo.Lines.Append(PingStr[i]);

    //Промотать список вниз
    PingMemo.SelStart := Length(PingMemo.Text);
    PingMemo.SelLength := 0;

    if PingMemo.Lines.Count > 500 then PingMemo.Clear;
  end;
end;

end.
