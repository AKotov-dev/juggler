unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, Process, DefaultTranslator, IniPropStorage;

type

  { TMainForm }

  TMainForm = class(TForm)
    ClearBox: TCheckBox;
    VPNService1: TComboBox;
    IniPropStorage1: TIniPropStorage;
    Interface1: TEdit;
    Interface2: TEdit;
    Label3: TLabel;
    Label4: TLabel;
    RadioGroup1: TRadioGroup;
    Shape1: TShape;
    Shape2: TShape;
    StaticText2: TStaticText;
    Timer1: TTimer;
    LogMemo: TMemo;
    StartBtn: TSpeedButton;
    StopBtn: TSpeedButton;
    VPNService2: TComboBox;
    procedure ClearBoxClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure VPNService1Change(Sender: TObject);
    procedure VPNService2Change(Sender: TObject);
  private

  public

  end;

var
  MainForm: TMainForm;

resourcestring
  SStartVPN = 'Connection attempt, wait...';
  SStopVPN = 'Stopping the connection';
  SCycleCompleted = 'The cycle is completed';

implementation

uses start_trd;

{$R *.lfm}

{ TMainForm }

procedure TMainForm.StopBtnClick(Sender: TObject);
var
  s: ansistring;
begin
  LogMemo.Append(SStopVPN);
  RunCommand('/bin/bash', ['-c', 'kill -9 $(cat /etc/juggler/pid); systemctl stop ' +
    VPNService1.Text + ' ' + VPNService2.Text + ' &'], s);
    RadioGroup1.Enabled := True;
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
var
  s: ansistring;
begin
  RunCommand('/bin/bash', ['-c', '[[ $(ip -br a | grep ' + Interface1.Text +
    ') ]] && echo "yes"'], s);
  if Trim(s) = 'yes' then Shape1.Brush.Color := clLime
  else
    Shape1.Brush.Color := clYellow;

  RunCommand('/bin/bash', ['-c', '[[ $(ip -br a | grep ' + Interface2.Text +
    ') ]] && echo "yes"'], s);
  if Trim(s) = 'yes' then Shape2.Brush.Color := clLime
  else
    Shape2.Brush.Color := clYellow;
end;

procedure TMainForm.VPNService1Change(Sender: TObject);
begin
  if VPNService1.ItemIndex <> 1 then Interface1.Text := 'tun0'
  else
    Interface1.Text := 'wg0';
end;

procedure TMainForm.VPNService2Change(Sender: TObject);
begin
  if VPNService2.ItemIndex <> 1 then Interface2.Text := 'tun0'
  else
    Interface2.Text := 'wg0';
end;

procedure TMainForm.StartBtnClick(Sender: TObject);
var
  D: TStringList;
  s: ansistring;
  FStart: TThread;
begin
  try
    D := TStringList.Create;

    if RadioGroup1.ItemIndex = 0 then
    begin
      D.Add('#!/bin/bash');
      D.Add('');

      D.Add('echo $$ > /etc/juggler/pid');
      D.Add('systemctl stop ' + VPNService1.Text + ' ' + VPNService2.Text);
      D.Add('systemctl restart ' + VPNService1.Text);

      D.Add('i=0; until [[ $(fping google.com) && $(ip -br a | grep ' +
        Interface1.Text + ') ]]; do sleep 1');

      D.Add('((i++)); if [[ $i == 8 ]]; then systemctl stop ' +
        VPNService1.Text + ' ' + VPNService2.Text + '; exit 1; else echo "' +
        Interface1.Text + ' attempt ${i}"; fi; done');

      D.Add('systemctl restart ' + VPNService2.Text);

      D.Add('i=0; until [[ $(fping google.com) && $(ip -br a | grep ' +
        Interface2.Text + ') ]]; do sleep 1');

      D.Add('((i++)); if [[ $i == 8 ]]; then systemctl stop ' +
        VPNService2.Text + ' ' + VPNService1.Text + '; exit 1; else echo "' +
        Interface2.Text + ' attempt ${i}"; fi; done');

      D.Add('systemctl stop ' + VPNService1.Text);
      D.Add('exit 0');
    end
    else
    begin
      D.Add('#!/bin/bash');
      D.Add('');

      D.Add('echo $$ > /etc/juggler/pid');
      D.Add('systemctl stop ' + VPNService1.Text + ' ' + VPNService2.Text);
      D.Add('systemctl restart ' + VPNService2.Text);

      D.Add('i=0; until [[ $(fping google.com) && $(ip -br a | grep ' +
        Interface2.Text + ') ]]; do sleep 1');

      D.Add('((i++)); if [[ $i == 8 ]]; then systemctl stop ' +
        VPNService2.Text + ' ' + VPNService1.Text + '; exit 1; else echo "' +
        Interface2.Text + ' attempt ${i}"; fi; done');

      D.Add('systemctl restart ' + VPNService1.Text);

      D.Add('i=0; until [[ $(fping google.com) && $(ip -br a | grep ' +
        Interface1.Text + ') ]]; do sleep 1');

      D.Add('((i++)); if [[ $i == 8 ]]; then systemctl stop ' +
        VPNService1.Text + ' ' + VPNService2.Text + '; exit 1; else echo "' +
        Interface1.Text + ' attempt ${i}"; fi; done');

      D.Add('systemctl stop ' + VPNService2.Text);
      D.Add('exit 0');
    end;

    D.SaveToFile('/etc/juggler/juggler.sh');

    RunCommand('/bin/bash', ['-c', 'chmod +x /etc/juggler/juggler.sh'], s);

    //Запуск VM
    FStart := Start.Create(False);
    FStart.Priority := tpNormal;
  finally
    D.Free;
  end;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  IniPropStorage1.Restore;
  Caption := Application.Title;
  Shape1.Top := RadioGroup1.Height div 4 - Shape1.Height;
  Shape2.Top := RadioGroup1.Height div 2 + RadioGroup1.Height div 8 + Shape2.Height;
  StopBtn.Height := StartBtn.Height;

  if FileExists('/etc/juggler/clear_cache') then ClearBox.Checked := True
  else
    ClearBox.Checked := False;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  if not DirectoryExists('/etc/juggler') then MkDir('/etc/juggler');
  IniPropStorage1.IniFileName := '/etc/juggler/juggler.conf';
end;

procedure TMainForm.ClearBoxClick(Sender: TObject);
begin
  if not ClearBox.Checked then DeleteFile('/etc/juggler/clear_cache')
  else
    LogMemo.Lines.SaveToFile('/etc/juggler/clear_cache');
end;

end.
