unit uSaveManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, uGameTypes, uGameState;

type
  { Struktur data untuk membaca ringkasan (metadata) save file tanpa meload keseluruhan state }
  TSaveMetaData = record
    IsValid: Boolean;
    Timestamp: string;
    SolCycle: Integer;
    UptimeSeconds: Int64;
  end;

  { TSaveManager menangani proses serialisasi dan deserialisasi state permainan ke format JSON }
  TSaveManager = class
  public
    { Menyimpan state ke file. Mengembalikan True jika berhasil }
    class function SaveGame(const FilePath: string; GameState: TGameStateManager): Boolean;

    { Memuat state dari file secara aman dengan nilai default. Mengembalikan True jika berhasil }
    class function LoadGame(const FilePath: string; GameState: TGameStateManager): Boolean;

    { Membaca metadata dari save file untuk ditampilkan di UI pemilihan slot }
    class function GetSaveMetaData(const FilePath: string): TSaveMetaData;
  end;

implementation

class function TSaveManager.SaveGame(const FilePath: string; GameState: TGameStateManager): Boolean;
var
  Root, StationNode, ModulesNode, ModuleItem: TJSONObject;
  m: TModuleType;
  StringList: TStringList;
begin
  Result := False;
  if not Assigned(GameState) then Exit;

  Root := TJSONObject.Create;
  try
    { Meta data save file }
    Root.Add('Version', 1.0);
    Root.Add('Phase', Integer(GameState.Phase));
    Root.Add('Timestamp', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));

    { Data Stasiun }
    StationNode := TJSONObject.Create;
    StationNode.Add('OxygenLevel', GameState.Station.Stats.OxygenLevel);
    StationNode.Add('PowerReserve', GameState.Station.Stats.PowerReserve);
    StationNode.Add('HullIntegrity', GameState.Station.Stats.HullIntegrity);

    { Data Sumber Daya Baru (Tech Points & Crew) }
    StationNode.Add('TechPoints', GameState.Station.Stats.TechPoints);
    StationNode.Add('TotalCrew', GameState.Station.Stats.TotalCrew);
    StationNode.Add('IdleCrew', GameState.Station.Stats.IdleCrew);

    StationNode.Add('SolCycle', GameState.Station.Data.SolCycle);
    StationNode.Add('UptimeSeconds', GameState.Station.Data.UptimeSeconds);
    Root.Add('Station', StationNode);

    { Data Modul }
    ModulesNode := TJSONObject.Create;
    for m := Low(TModuleType) to High(TModuleType) do
    begin
      ModuleItem := TJSONObject.Create;
      ModuleItem.Add('Status', Integer(GameState.Modules[m]^.Status));
      ModuleItem.Add('RepairProgress', GameState.Modules[m]^.RepairProgress);

      { Data Upgrade dan Alokasi Kru }
      ModuleItem.Add('UpgradeLevel', GameState.Modules[m]^.UpgradeLevel);
      ModuleItem.Add('AssignedCrew', GameState.Modules[m]^.AssignedCrew);

      { Menyimpan hasil kalkulasi akhir daya dan waktu perbaikan agar aman saat diload }
      ModuleItem.Add('PowerDraw', GameState.Modules[m]^.PowerDraw);
      ModuleItem.Add('RepairTimeReq', GameState.Modules[m]^.RepairTimeReq);

      { Gunakan index enum sebagai key JSON }
      ModulesNode.Add(IntToStr(Integer(m)), ModuleItem);
    end;
    Root.Add('Modules', ModulesNode);

    { Proses penulisan ke sistem file }
    StringList := TStringList.Create;
    try
      StringList.Text := Root.AsJSON;
      StringList.SaveToFile(FilePath);
      Result := True;
    finally
      StringList.Free;
    end;
  except
    Result := False;
  end;

  { Objek JSON anak (StationNode, ModulesNode) akan otomatis dibebaskan saat Root dibebaskan }
  Root.Free;
end;

class function TSaveManager.LoadGame(const FilePath: string; GameState: TGameStateManager): Boolean;
var
  Root, StationNode, ModulesNode, ModuleItem: TJSONObject;
  JSONData: TJSONData;
  FileContent: TStringList;
  m: TModuleType;
  ModTypeStr: string;
  TempData: TStationData;
  TempStats: TResourceStats;
begin
  Result := False;
  if not FileExists(FilePath) or not Assigned(GameState) then Exit;

  FileContent := TStringList.Create;
  try
    FileContent.LoadFromFile(FilePath);
    JSONData := GetJSON(FileContent.Text);
    try
      if JSONData.JSONType = jtObject then
      begin
        Root := TJSONObject(JSONData);

        { Menggunakan metode Get() dengan default fallback value untuk mencegah crash pada data lama }
        GameState.Phase := TGamePhase(Root.Get('Phase', Integer(gpMainMenu)));

        StationNode := TJSONObject(Root.Find('Station'));
        if Assigned(StationNode) then
        begin
          GameState.Station.OxygenLevel := StationNode.Get('OxygenLevel', 100.0);
          GameState.Station.PowerReserve := StationNode.Get('PowerReserve', 100.0);
          GameState.Station.HullIntegrity := StationNode.Get('HullIntegrity', 100.0);

          { Memuat data resource baru (Upgrade/Crew) menggunakan variabel sementara }
          TempStats := GameState.Station.Stats;
          TempStats.TechPoints := StationNode.Get('TechPoints', 0.0);
          TempStats.TotalCrew := StationNode.Get('TotalCrew', 3);
          TempStats.IdleCrew := StationNode.Get('IdleCrew', 3);
          GameState.Station.Stats := TempStats;

          TempData := GameState.Station.Data;
          TempData.SolCycle := StationNode.Get('SolCycle', 1);
          TempData.UptimeSeconds := StationNode.Get('UptimeSeconds', Int64(0));
          GameState.Station.Data := TempData;
        end;

        ModulesNode := TJSONObject(Root.Find('Modules'));
        if Assigned(ModulesNode) then
        begin
          for m := Low(TModuleType) to High(TModuleType) do
          begin
            ModTypeStr := IntToStr(Integer(m));
            ModuleItem := TJSONObject(ModulesNode.Find(ModTypeStr));
            if Assigned(ModuleItem) then
            begin
              GameState.Modules.SetModuleStatus(m, TModuleStatus(ModuleItem.Get('Status', Integer(msOffline))));
              GameState.Modules[m]^.RepairProgress := ModuleItem.Get('RepairProgress', 0.0);

              { Memuat status Upgrade dan Kru }
              GameState.Modules[m]^.UpgradeLevel := ModuleItem.Get('UpgradeLevel', 0);
              GameState.Modules[m]^.AssignedCrew := ModuleItem.Get('AssignedCrew', 0);

              { Memuat atribut kalkulasi akhir, atau gunakan default jika save file berasal dari versi lama }
              GameState.Modules[m]^.PowerDraw := ModuleItem.Get('PowerDraw', GameState.Modules[m]^.PowerDraw);
              GameState.Modules[m]^.RepairTimeReq := ModuleItem.Get('RepairTimeReq', GameState.Modules[m]^.RepairTimeReq);
            end;
          end;
        end;

        { Reset status krisis agar tidak ada krisis instan saat load game }
        GameState.Crisis.ResetToDefault;

        Result := True;
      end;
    finally
      JSONData.Free;
    end;
  except
    Result := False;
  end;
  FileContent.Free;
end;

class function TSaveManager.GetSaveMetaData(const FilePath: string): TSaveMetaData;
var
  Root, StationNode: TJSONObject;
  JSONData: TJSONData;
  FileContent: TStringList;
begin
  Result.IsValid := False;
  Result.Timestamp := 'N/A';
  Result.SolCycle := 0;
  Result.UptimeSeconds := 0;

  if not FileExists(FilePath) then Exit;

  FileContent := TStringList.Create;
  try
    FileContent.LoadFromFile(FilePath);
    try
      JSONData := GetJSON(FileContent.Text);
      try
        if JSONData.JSONType = jtObject then
        begin
          Root := TJSONObject(JSONData);
          Result.Timestamp := Root.Get('Timestamp', 'N/A');

          StationNode := TJSONObject(Root.Find('Station'));
          if Assigned(StationNode) then
          begin
            Result.SolCycle := StationNode.Get('SolCycle', 0);
            Result.UptimeSeconds := StationNode.Get('UptimeSeconds', Int64(0));
            Result.IsValid := True;
          end;
        end;
      finally
        JSONData.Free;
      end;
    except
      { Jika JSON invalid/corrupt, tangkap error dan kembalikan IsValid = False }
    end;
  finally
    FileContent.Free;
  end;
end;

end.
