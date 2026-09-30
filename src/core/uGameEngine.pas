unit uGameEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGameTypes, uGameState, uStationModel, uModuleManager, uCrisisSystem, uAudioManager;

type
  { Event delegate untuk mencatat log ke antarmuka }
  TLogMessageEvent = procedure(const Msg: string; IsCritical: Boolean) of object;

  { Event delegate untuk mengakhiri permainan }
  TGameOverEvent = procedure(IsVictory: Boolean) of object;

  { TGameEngine menangani master loop, kalkulasi delta sumber daya, dan integrasi antar sistem }
  TGameEngine = class
  private
    FGameState: TGameStateManager;
    FAudioManager: TAudioManager;
    FSolTimer: Double; { Akumulator waktu untuk menghitung pergantian Siklus Sol }

    { Variabel untuk efek visual (Game Feel) }
    FShakeIntensity: Double;
    FBlinkTimer: Double;
    FGlobalBlink: Boolean;

    { Variabel untuk sistem Deep Space Encounters }
    FEncounterTimer: Double;
    FEncounterSpawnTimer: Double;

    FOnUpdateUI: TNotifyEvent;
    FOnLogMessage: TLogMessageEvent;
    FOnGameOver: TGameOverEvent;

    { Handler untuk event yang dipancarkan oleh CrisisSystem }
    procedure CrisisNotifyHandler(CrisisType: TCrisisType; const Msg: string);
    procedure CrisisEffectHandler(CrisisType: TCrisisType; DeltaSeconds: Double);

    procedure CheckWinLossConditions;
    procedure ApplyDifficultyScaling;
  public
    constructor Create;
    destructor Destroy; override;

    { Memulai ulang game dari awal }
    procedure StartNewGame;

    { Dieksekusi setiap frame/tick oleh timer utama antarmuka }
    procedure Update(DeltaSeconds: Double);

    { Mengeksekusi Protokol Pilihan Darurat (Emergency Override Directives) }
    procedure ExecuteDirective(Directive: TEmergencyDirective);

    { Memproses respons pemain terhadap Transmisi Entitas Misterius }
    procedure HandleEncounterAction(Action: TEncounterAction);

    { Meneruskan pesan ke antarmuka log }
    procedure LogEvent(const Msg: string; IsCritical: Boolean = False);

    { Memicu guncangan layar dengan intensitas tertentu }
    procedure TriggerShake(Intensity: Double);

    property GameState: TGameStateManager read FGameState;
    property AudioManager: TAudioManager read FAudioManager;

    { Properti akses baca untuk sistem Renderer }
    property ShakeIntensity: Double read FShakeIntensity;
    property GlobalBlink: Boolean read FGlobalBlink;

    { Hooks untuk antarmuka pengguna (View/Form) }
    property OnUpdateUI: TNotifyEvent read FOnUpdateUI write FOnUpdateUI;
    property OnLogMessage: TLogMessageEvent read FOnLogMessage write FOnLogMessage;
    property OnGameOver: TGameOverEvent read FOnGameOver write FOnGameOver;
  end;

implementation

{ TGameEngine }

constructor TGameEngine.Create;
begin
  inherited Create;
  FGameState := TGameStateManager.Create;
  FAudioManager := TAudioManager.Create;
  FSolTimer := 0.0;
  FShakeIntensity := 0.0;
  FBlinkTimer := 0.0;
  FGlobalBlink := False;
  FEncounterTimer := 0.0;
  FEncounterSpawnTimer := 0.0;

  { Menghubungkan event dari subsistem krisis ke engine }
  FGameState.Crisis.OnWarning := @CrisisNotifyHandler;
  FGameState.Crisis.OnStrike := @CrisisNotifyHandler;
  FGameState.Crisis.OnResolved := @CrisisNotifyHandler;
  FGameState.Crisis.OnEffectTick := @CrisisEffectHandler;
end;

destructor TGameEngine.Destroy;
begin
  FreeAndNil(FAudioManager);
  FreeAndNil(FGameState);
  inherited Destroy;
end;

procedure TGameEngine.LogEvent(const Msg: string; IsCritical: Boolean = False);
begin
  if Assigned(FOnLogMessage) then
    FOnLogMessage(Msg, IsCritical);
end;

procedure TGameEngine.TriggerShake(Intensity: Double);
begin
  FShakeIntensity := FShakeIntensity + Intensity;
  { Batasi intensitas guncangan agar tampilan tidak keluar dari batas layar }
  if FShakeIntensity > 20.0 then
    FShakeIntensity := 20.0;
end;

procedure TGameEngine.CrisisNotifyHandler(CrisisType: TCrisisType; const Msg: string);
begin
  { Meneruskan notifikasi krisis ke UI Log & Putar Suara Alarm }
  LogEvent(Msg, True);
  if Assigned(FAudioManager) then
    FAudioManager.PlaySound(sfxAlarm);
end;

procedure TGameEngine.CrisisEffectHandler(CrisisType: TCrisisType; DeltaSeconds: Double);
var
  ShieldActive: Boolean;
  DifficultyMultiplier: Double;
begin
  ShieldActive := FGameState.Modules.IsModuleOnline(mtDeflectorShield);

  { Pengali tingkat kesulitan berdasarkan Siklus Sol (Sol 1 s.d. 14) }
  DifficultyMultiplier := 1.0 + (FGameState.Station.Data.SolCycle * 0.1);

  case CrisisType of
    ctSolarFlare:
      begin
        { Radiasi semakin mematikan di Sol-Sol akhir }
        if not ShieldActive then
          FGameState.Station.ApplyHullDamage(1.5 * DifficultyMultiplier * DeltaSeconds);
      end;

    ctMeteorShower:
      begin
        { Hujan meteor memberikan dampak damage dan guncangan yang berskala sesuai Sol }
        if ShieldActive then
        begin
          FGameState.Station.ApplyHullDamage(0.5 * DifficultyMultiplier * DeltaSeconds);
          TriggerShake(2.0 * DeltaSeconds);
        end
        else
        begin
          FGameState.Station.ApplyHullDamage(3.5 * DifficultyMultiplier * DeltaSeconds);
          TriggerShake(15.0 * DeltaSeconds);
        end;
      end;

    ctOxygenLeak:
      begin
        { Kebocoran oksigen semakin agresif menguras suplai di hari-hari menjelang akhir }
        FGameState.Station.OxygenLevel := FGameState.Station.Stats.OxygenLevel - (4.0 * DifficultyMultiplier * DeltaSeconds);
      end;

    ctPowerSurge:
      begin
        { Lonjakan daya menguras cadangan baterai stasiun lebih cepat pada Sol tinggi }
        FGameState.Station.PowerReserve := FGameState.Station.Stats.PowerReserve - (10.0 * DifficultyMultiplier * DeltaSeconds);
      end;
  end;
end;

procedure TGameEngine.ApplyDifficultyScaling;
var
  CurrentSol: Integer;
begin
  CurrentSol := FGameState.Station.Data.SolCycle;

  { Menyesuaikan interval atau tingkat ancaman krisis berdasarkan Sol aktif }
  if CurrentSol <= 3 then
  begin
    { Fase 1: Relatif tenang, memberikan ruang adaptasi bagi pemain }
  end
  else if CurrentSol <= 7 then
  begin
    { Fase 2: Eskalasi menengah }
  end
  else if CurrentSol <= 11 then
  begin
    { Fase 3: Krisis tingkat lanjut, waktu tanggap diperketat }
  end
  else
  begin
    { Fase 4: Sol 12-14 (Fase Survival Ekstrem menjelang akhir misi) }
  end;
end;

procedure TGameEngine.ExecuteDirective(Directive: TEmergencyDirective);
begin
  if FGameState.Phase <> gpPlaying then Exit;

  case Directive of
    edShieldBoost:
      begin
        { Opsi A: Diversifikasikan daya ke perisai, memulihkan integritas lambung atau menahan krisis, namun menguras oksigen }
        FGameState.Station.OxygenLevel := Max(0.0, FGameState.Station.Stats.OxygenLevel - 15.0);
        FGameState.Station.ApplyHullDamage(-10.0); { Memulihkan sedikit lambung / meredam hantaman }
        LogEvent('OVERRIDE [A] EXECUTED: SHIELD BOOSTED. OXYGEN COMPROMISED (-15%).', True);
        TriggerShake(8.0);
        if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxSuccess);
      end;

    edJettisonCargo:
      begin
        { Opsi B: Buang sektor kargo untuk mengamankan lambung dari hantaman, mengorbankan Tech Points }
        FGameState.Station.AddTechPoints(-FGameState.Station.Stats.TechPoints); { Menghapus seluruh Tech Points }
        FGameState.Station.ApplyHullDamage(-25.0); { Memperbaiki lambung secara instan }
        LogEvent('OVERRIDE [B] EXECUTED: CARGO JETTISONED. HULL STABILIZED. TECH POINTS LOST.', True);
        TriggerShake(4.0);
        if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxSuccess);
      end;
  end;
end;

procedure TGameEngine.HandleEncounterAction(Action: TEncounterAction);
var
  TempData: TStationData;
  TempStats: TResourceStats;
  Chance: Integer;
begin
  if FGameState.Phase <> gpPlaying then Exit;

  TempData := FGameState.Station.Data;
  if TempData.ActiveEncounter = etNone then Exit;

  if Action = eaIgnore then
  begin
    LogEvent('TRANSMISSION IGNORED. RESUMING NORMAL OPERATION.', False);
    if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxClick);
  end
  else if Action = eaDecrypt then
  begin
    Chance := Random(100); { Nilai 0 s.d. 99 }

    case TempData.ActiveEncounter of
      etDerelictShip:
        if Chance < 50 then { 50% Reward }
        begin
          FGameState.Station.ApplyHullDamage(-25.0);
          LogEvent('DERELICT SALVAGED: RESOURCE CACHE FOUND. HULL REPAIRED (+25%)', False);
          if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxSuccess);
        end
        else { 50% Risk }
        begin
          FGameState.Station.ApplyHullDamage(20.0);
          LogEvent('TRAP TRIGGERED: KINETIC EXPLOSION! HULL DAMAGED (-20%)', True);
          TriggerShake(8.0);
          if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxError);
        end;

      etUnknownSOS:
        if Chance < 50 then { 50% Reward }
        begin
          TempStats := FGameState.Station.Stats;
          TempStats.TotalCrew := TempStats.TotalCrew + 1;
          TempStats.IdleCrew := TempStats.IdleCrew + 1;
          FGameState.Station.Stats := TempStats;
          LogEvent('SOS RESPONDED: LONE SURVIVOR RESCUED. CREW +1', False);
          if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxSuccess);
        end
        else { 50% Risk }
        begin
          FGameState.Station.ApplyHullDamage(15.0);
          LogEvent('PIRATE AMBUSH! STATION TOOK FIRE (-15% HULL)', True);
          TriggerShake(10.0);
          if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxError);
        end;

      etAlienSignal:
        if Chance < 50 then { 50% Reward }
        begin
          FGameState.Station.AddTechPoints(150.0);
          LogEvent('SIGNAL DECRYPTED: ALIEN TECH DATA ACQUIRED (+150 TP)', False);
          if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxSuccess);
        end
        else { 50% Risk }
        begin
          FGameState.Modules.SetModuleStatus(mtCommsArray, msOffline);
          FGameState.Modules.SetModuleStatus(mtResearchLab, msOffline);
          LogEvent('VIRUS UPLOADED: COMMS & LAB FORCED OFFLINE!', True);
          TriggerShake(5.0);
          if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxError);
        end;
    end;
  end;

  { Bersihkan status encounter setelah diputuskan }
  TempData.ActiveEncounter := etNone;
  TempData.EncounterTimeLeft := 0;
  FGameState.Station.Data := TempData;
  FEncounterTimer := 0.0;
end;

procedure TGameEngine.StartNewGame;
var
  TempData: TStationData;
  TempStats: TResourceStats;
begin
  FGameState.ResetGame;
  FSolTimer := 0.0;
  FShakeIntensity := 0.0;
  FEncounterTimer := 0.0;
  FEncounterSpawnTimer := 0.0;

  { Reset Encounter stat di data stasiun }
  TempData := FGameState.Station.Data;
  TempData.ActiveEncounter := etNone;
  TempData.EncounterTimeLeft := 0;
  FGameState.Station.Data := TempData;

  { Reset Suhu Inti (Core Temperature) ke titik aman }
  TempStats := FGameState.Station.Stats;
  TempStats.CoreTemperature := 20.0;
  FGameState.Station.Stats := TempStats;

  { Boot Log & Tutorial Instruksi Awal untuk Pemain }
  LogEvent('SYSTEM BOOT SEQUENCE... OK', False);
  LogEvent('CHECKING LIFE SUPPORT & POWER RESERVES... NOMINAL', False);
  LogEvent('INSTRUCTION: SURVIVE 14 SOL CYCLES. MONITOR RADAR FOR ANOMALIES.', False);
  LogEvent('ORBITAL COMMAND INITIALIZED. GOOD LUCK, COO.', False);

  if Assigned(FAudioManager) then
    FAudioManager.PlaySound(sfxSuccess);

  if Assigned(FAudioManager) then
    FAudioManager.StartAmbient('ambient.wav');
end;

procedure TGameEngine.CheckWinLossConditions;
begin
  { Kondisi Kalah: Integritas lambung habis atau Oksigen habis }
  if (FGameState.Station.Stats.HullIntegrity <= 0.0) or (FGameState.Station.Stats.OxygenLevel <= 0.0) then
  begin
    FGameState.Phase := gpGameOver;
    if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxError);
    if Assigned(FOnGameOver) then FOnGameOver(False);
  end
  { Kondisi Menang: Berhasil bertahan selama 14 Siklus Sol }
  else if FGameState.Station.Data.SolCycle > 14 then
  begin
    FGameState.Phase := gpVictory;
    if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxSuccess);
    if Assigned(FOnGameOver) then FOnGameOver(True);
  end;
end;

procedure TGameEngine.Update(DeltaSeconds: Double);
var
  OxyDelta, PowerDelta, TotalDraw, MaxPowerOutput: Double;
  HeatDelta: Double;
  RandMod: TModuleType;
  TempStats: TResourceStats;
  TempData: TStationData;
begin
  if FGameState.Phase <> gpPlaying then Exit;

  { Update efek visual (Game Feel) }
  if FShakeIntensity > 0 then
  begin
    FShakeIntensity := FShakeIntensity - (DeltaSeconds * 10.0);
    if FShakeIntensity < 0 then
      FShakeIntensity := 0;
  end;

  FBlinkTimer := FBlinkTimer + DeltaSeconds;
  if FBlinkTimer >= 0.5 then { Kedip setiap 0.5 detik }
  begin
    FBlinkTimer := FBlinkTimer - 0.5;
    FGlobalBlink := not FGlobalBlink;
  end;

  { 1. Kalkulasi Produksi vs Konsumsi Daya }
  MaxPowerOutput := 100.0;
  if not FGameState.Modules.IsModuleOnline(mtMainGenerator) then
    MaxPowerOutput := 0.0;

  TotalDraw := FGameState.Modules.GetTotalPowerConsumption;

  { Menggunakan variabel sementara untuk record Stats }
  TempStats := FGameState.Station.Stats;
  TempStats.TotalPowerOutput := MaxPowerOutput;
  TempStats.PowerConsumption := TotalDraw;

  { --- SISTEM BARU: Manajemen Suhu Inti (Core Heat) --- }
  HeatDelta := -2.5; { Pendinginan pasif ke luar angkasa (Venting) }

  { Setiap modul aktif menyumbang peningkatan suhu }
  if FGameState.Modules.IsModuleOnline(mtMainGenerator) then HeatDelta := HeatDelta + 2.0;
  if FGameState.Modules.IsModuleOnline(mtDeflectorShield) then HeatDelta := HeatDelta + 1.5;
  if FGameState.Modules.IsModuleOnline(mtResearchLab) then HeatDelta := HeatDelta + 1.0;
  if FGameState.Modules.IsModuleOnline(mtLifeSupport) then HeatDelta := HeatDelta + 0.5;
  if FGameState.Modules.IsModuleOnline(mtCommsArray) then HeatDelta := HeatDelta + 0.5;

  TempStats.CoreTemperature := TempStats.CoreTemperature + (HeatDelta * DeltaSeconds);
  if TempStats.CoreTemperature < 0.0 then TempStats.CoreTemperature := 0.0;

  { Meltdown terpicu jika suhu mencapai 100% }
  if TempStats.CoreTemperature >= 100.0 then
  begin
    TempStats.CoreTemperature := 60.0; { Suhu turun darurat akibat ledakan pelepasan tekanan }
    LogEvent('CRITICAL: CORE MELTDOWN! HEAT CAPACITY EXCEEDED 100%.', True);
    TriggerShake(15.0);
    if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxError);

    { Matikan paksa (rusak) satu modul secara acak }
    RandMod := TModuleType(Random(5));
    FGameState.Modules.SetModuleStatus(RandMod, msDamaged);
    LogEvent('MELTDOWN DAMAGE: MODULE ' + IntToStr(Integer(RandMod)) + ' COMPROMISED!', True);

    { Berikan kerusakan lambung }
    FGameState.Station.ApplyHullDamage(15.0);
  end;
  { ---------------------------------------------------- }

  FGameState.Station.Stats := TempStats;

  { Selisih daya akan mengisi ulang atau menguras Power Reserve }
  PowerDelta := MaxPowerOutput - TotalDraw;

  { 2. Kalkulasi Konsumsi Oksigen }
  OxyDelta := -1.5;
  if FGameState.Modules.IsModuleOnline(mtLifeSupport) then
    OxyDelta := OxyDelta + 2.0;

  { Jika cadangan daya habis, matikan modul (simulasi pemadaman) }
  if (FGameState.Station.Stats.PowerReserve <= 0) and (PowerDelta < 0) then
  begin
    LogEvent('WARNING: TOTAL POWER FAILURE. MODULES OFFLINE.', True);
    FGameState.Modules.SetModuleStatus(mtLifeSupport, msOffline);
    FGameState.Modules.SetModuleStatus(mtDeflectorShield, msOffline);
    FGameState.Modules.SetModuleStatus(mtResearchLab, msOffline);
    FGameState.Modules.SetModuleStatus(mtCommsArray, msOffline);
    PowerDelta := 0.0;

    TriggerShake(5.0);
    if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxError);
  end;

  { 3. Terapkan pembaruan ke Model Stasiun }
  FGameState.Station.UpdateTick(DeltaSeconds, OxyDelta, PowerDelta);

  { 3b. Produksi Tech Points dari Research Lab }
  if FGameState.Modules.IsModuleOnline(mtResearchLab) then
  begin
    FGameState.Station.AddTechPoints((1.0 + (FGameState.Modules[mtResearchLab]^.AssignedCrew * 0.5)) * DeltaSeconds);
  end;

  { 4. Proses subsistem lainnya }
  FGameState.Modules.ProcessRepairs(DeltaSeconds);
  FGameState.Crisis.UpdateTick(DeltaSeconds);

  { --- SISTEM BARU: Deep Space Encounters Update --- }
  TempData := FGameState.Station.Data;
  if TempData.ActiveEncounter <> etNone then
  begin
    FEncounterTimer := FEncounterTimer - DeltaSeconds;
    TempData.EncounterTimeLeft := Ceil(FEncounterTimer);

    { Sinyal hilang jika waktu habis }
    if FEncounterTimer <= 0 then
    begin
      LogEvent('TRANSMISSION LOST. SIGNAL DEGRADED.', False);
      TempData.ActiveEncounter := etNone;
      TempData.EncounterTimeLeft := 0;
    end;
    FGameState.Station.Data := TempData;
  end
  else
  begin
    { Pengecekan kemunculan transmisi acak (tiap 10 detik, chance 15%) }
    FEncounterSpawnTimer := FEncounterSpawnTimer + DeltaSeconds;
    if FEncounterSpawnTimer >= 10.0 then
    begin
      FEncounterSpawnTimer := 0.0;
      { Hanya muncul jika tidak ada krisis alam yang sedang aktif }
      if (FGameState.Crisis.CurrentCrisis = ctNone) and (Random(100) < 15) then
      begin
        TempData.ActiveEncounter := TEncounterType(Random(3) + 1); { Random antara etDerelictShip s.d. etAlienSignal }
        FEncounterTimer := 15.0; { Pemain punya 15 detik untuk merespons }
        TempData.EncounterTimeLeft := 15;

        LogEvent('UNKNOWN TRANSMISSION DETECTED! [Y] DECRYPT OR [N] IGNORE?', True);
        if Assigned(FAudioManager) then FAudioManager.PlaySound(sfxAlarm);

        FGameState.Station.Data := TempData;
      end;
    end;
  end;
  { ------------------------------------------------- }

  { 5. Kalkulasi Siklus Waktu (1 Sol = 60 Detik Dunia Nyata) }
  FSolTimer := FSolTimer + DeltaSeconds;
  if FSolTimer >= 60.0 then
  begin
    FSolTimer := FSolTimer - 60.0;

    { Menggunakan variabel sementara untuk record Data }
    TempData := FGameState.Station.Data;
    TempData.SolCycle := TempData.SolCycle + 1;
    FGameState.Station.Data := TempData;

    LogEvent('NEW SOL CYCLE REACHED: SOL ' + IntToStr(FGameState.Station.Data.SolCycle), False);

    { Terapkan eskalasi tingkat kesulitan berdasarkan siklus baru }
    ApplyDifficultyScaling;
  end;

  { 6. Periksa Kondisi Menang/Kalah }
  CheckWinLossConditions;

  { 7. Pancarkan notifikasi ke antarmuka pengguna untuk menggambar ulang grafik }
  if Assigned(FOnUpdateUI) then
    FOnUpdateUI(Self);
end;

end.
