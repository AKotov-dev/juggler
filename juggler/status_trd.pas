unit status_trd;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, Forms, Controls, SysUtils, Process, Graphics;

type
  LEDStatus = class(TThread)
  private

    { Private declarations }
  protected
  var
    ResultStr: TStringList;

    procedure Execute; override;
    procedure ShowStatus;

  end;

implementation

uses unit1;

{ TRD }

//Отображение статуса светодиодов
procedure LEDStatus.Execute;
var
  ScanProcess: TProcess;
begin
  FreeOnTerminate := True; //Уничтожать по завершении

  while not Terminated do
    try
      ResultStr := TStringList.Create;

      ScanProcess := TProcess.Create(nil);

      ScanProcess.Executable := 'bash';
      ScanProcess.Parameters.Add('-c');
      ScanProcess.Options := [poUsePipes, poWaitOnExit];

      ScanProcess.Parameters.Add(
        '[[ $(ip -br a | grep ' + MainForm.Interface1.Text +
        ') ]] && echo "yes" || echo "no"; [[ $(ip -br a | grep ' +
        MainForm.Interface2.Text + ') ]] && echo "yes" || echo "no"');

      ScanProcess.Execute;

      ResultStr.LoadFromStream(ScanProcess.Output);
      Synchronize(@ShowStatus);

      Sleep(500);
    finally
      ResultStr.Free;
      ScanProcess.Free;
    end;
end;

//Отображение статуса
procedure LEDStatus.ShowStatus;
begin
  with MainForm do
  begin
    //Состояние панели и кнопки "Старт"
    if (ResultStr[0] = 'yes') or (ResultStr[1] = 'yes') then
    begin
      RadioGroup1.Enabled := False;
      StartBtn.Enabled := False;
    end
    else
    begin
      RadioGroup1.Enabled := True;
      StartBtn.Enabled := True;
    end;

    //Светодиоды
    if ResultStr[0] = 'yes' then
      Shape1.Brush.Color := clLime
    else
      Shape1.Brush.Color := clYellow;
    Shape1.Repaint;

    if ResultStr[1] = 'yes' then
      Shape2.Brush.Color := clLime
    else
      Shape2.Brush.Color := clYellow;
    Shape2.Repaint;
  end;
end;

end.
