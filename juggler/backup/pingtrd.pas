unit PingTRD;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, Controls, SysUtils, Process, Graphics, Dialogs;

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
      PingProcess.Options := PingProcess.Options + [poWaitOnExit, poUsePipes, poStderrToOutPut];

      PingProcess.Parameters.Add('ping google.com');
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
  showmessage('1111');
//Вывод построчно
for i := 0 to PingStr.Count - 1 do
  MainForm.PingMemo.Lines.Append(PingStr[i]);

//Промотать список вниз
MainForm.PingMemo.SelStart := Length(MainForm.PingMemo.Text);
MainForm.PingMemo.SelLength := 0;
end;

end.
