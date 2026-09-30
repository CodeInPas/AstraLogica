unit uGameState;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uGameTypes, uStationModel, uModuleManager, uCrisisSystem;

type
  { TGameStateManager bertindak sebagai kontainer pusat untuk seluruh state permainan }
  TGameStateManager = class
  private
    FPhase: TGamePhase;
    FStation: TStationModel;
    FModules: TModuleManager;
    FCrisis: TCrisisSystem;
    procedure SetPhase(const AValue: TGamePhase);
  public
    constructor Create;
    destructor Destroy; override;

    { Memulai ulang seluruh parameter, modul, dan krisis ke kondisi awal permainan }
    procedure ResetGame;

    { Akses properti ke instansiasi subsistem }
    property Phase: TGamePhase read FPhase write SetPhase;
    property Station: TStationModel read FStation;
    property Modules: TModuleManager read FModules;
    property Crisis: TCrisisSystem read FCrisis;
  end;

implementation

{ TGameStateManager }

constructor TGameStateManager.Create;
begin
  inherited Create;
  FPhase := gpMainMenu;
  FStation := TStationModel.Create;
  FModules := TModuleManager.Create;
  FCrisis := TCrisisSystem.Create;
end;

destructor TGameStateManager.Destroy;
begin
  FreeAndNil(FCrisis);
  FreeAndNil(FModules);
  FreeAndNil(FStation);
  inherited Destroy;
end;

procedure TGameStateManager.SetPhase(const AValue: TGamePhase);
begin
  if FPhase = AValue then Exit;
  FPhase := AValue;
end;

procedure TGameStateManager.ResetGame;
begin
  FStation.ResetToDefault;
  FModules.ResetToDefault;
  FCrisis.ResetToDefault;
  FPhase := gpPlaying;
end;

end.

