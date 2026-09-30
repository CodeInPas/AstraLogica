program AstraLogica;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // LCL widgetset
  Forms,
  uGameTypes in 'src/core/uGameTypes.pas',
  uGameState in 'src/core/uGameState.pas',
  uGameEngine in 'src/core/uGameEngine.pas', BASS,
  uStationModel in 'src/model/uStationModel.pas',
  uModuleManager in 'src/model/uModuleManager.pas',
  uCrisisSystem in 'src/model/uCrisisSystem.pas',
  uSaveManager in 'src/storage/uSaveManager.pas',
  uPanelRenderer in 'src/renderer/uPanelRenderer.pas',
  uRadarRenderer in 'src/renderer/uRadarRenderer.pas',
  uMainForm in 'src/view/uMainForm.pas',
  uSaveLoadForm in 'src/view/uSaveLoadForm.pas',
  uAudioManager in 'src/model/uAudioManager.pas';
{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
