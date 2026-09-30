unit uPanelRenderer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Types, Math, BGRABitmap, BGRABitmapTypes,
  uGameTypes, uGameState;

type
  { TPanelRenderer bertugas menggambar elemen UI statis dan dinamis }
  TPanelRenderer = class
  private
    { Helper Warna yang dijamin aman untuk lintas platform (Anti-Endian Issue) }
    class function C_PANEL: TBGRAPixel; inline;
    class function C_TEXT: TBGRAPixel; inline;
    class function C_GRID: TBGRAPixel; inline;
    class function C_WARN: TBGRAPixel; inline;
    class function C_CRIT: TBGRAPixel; inline;
    class function C_OFF: TBGRAPixel; inline;

    { Helper internal untuk menggambar progress bar bergaya sci-fi }
    class procedure DrawProgressBar(ABitmap: TBGRABitmap; ARect: TRect;
      Value, MaxValue: Double; BarColor: TBGRAPixel);
  public
    class procedure RenderCoreStatus(ABitmap: TBGRABitmap; Bounds: TRect; GameState: TGameStateManager; IsBlink: Boolean);
    class procedure RenderSystemModules(ABitmap: TBGRABitmap; Bounds: TRect; GameState: TGameStateManager; IsBlink: Boolean);
  end;

implementation

{ Implementasi Palet Warna }
class function TPanelRenderer.C_PANEL: TBGRAPixel; begin Result := BGRA(26, 28, 35, 255); end;
class function TPanelRenderer.C_TEXT: TBGRAPixel; begin Result := BGRA(0, 255, 204, 255); end;
class function TPanelRenderer.C_GRID: TBGRAPixel; begin Result := BGRA(0, 160, 120, 255); end;
class function TPanelRenderer.C_WARN: TBGRAPixel; begin Result := BGRA(255, 179, 0, 255); end;
class function TPanelRenderer.C_CRIT: TBGRAPixel; begin Result := BGRA(255, 42, 42, 255); end;
class function TPanelRenderer.C_OFF: TBGRAPixel; begin Result := BGRA(74, 77, 89, 255); end;

class procedure TPanelRenderer.DrawProgressBar(ABitmap: TBGRABitmap; ARect: TRect;
  Value, MaxValue: Double; BarColor: TBGRAPixel);
var
  FillWidth: Integer;
  SegmentRect: TRect;
  i, SegmentCount, Spacing: Integer;
begin
  { Gambar bingkai luar bar transparan }
  ABitmap.Rectangle(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom,
                    BarColor, BGRA(0, 0, 0, 0), dmSet);

  if MaxValue <= 0 then Exit;

  { Hitung rasio pengisian }
  FillWidth := Round(((ARect.Right - ARect.Left - 4) * Value) / MaxValue);
  if FillWidth <= 0 then Exit;

  { Gaya segmented bar (terpotong-potong) }
  SegmentCount := 10;
  Spacing := 2;

  for i := 0 to SegmentCount - 1 do
  begin
    SegmentRect.Left := ARect.Left + 2 + (i * ((ARect.Right - ARect.Left - 4) div SegmentCount));
    SegmentRect.Right := SegmentRect.Left + ((ARect.Right - ARect.Left - 4) div SegmentCount) - Spacing;
    SegmentRect.Top := ARect.Top + 2;
    SegmentRect.Bottom := ARect.Bottom - 2;

    if SegmentRect.Right > (ARect.Left + 2 + FillWidth) then Break;

    ABitmap.FillRect(SegmentRect.Left, SegmentRect.Top, SegmentRect.Right, SegmentRect.Bottom, BarColor, dmSet);
  end;
end;

class procedure TPanelRenderer.RenderCoreStatus(ABitmap: TBGRABitmap; Bounds: TRect; GameState: TGameStateManager; IsBlink: Boolean);
var
  yOffset: Integer;
  StatColor, ChartColor: TBGRAPixel;
  sText: string;
  ChartRect: TRect;
  px, py, LastPy: Integer;
  TimeVal, Stress, WaveOffset: Double;
begin
  { Background & Border }
  ABitmap.FillRect(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, C_PANEL, dmSet);
  ABitmap.Rectangle(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, C_TEXT, BGRA(0,0,0,0), dmSet);

  ABitmap.FontHeight := 14;
  ABitmap.FontAntialias := True;

  yOffset := Bounds.Top + 10;

  ABitmap.TextOut(Bounds.Left + 10, yOffset, '[ R ] CORE STATUS', C_TEXT, taLeftJustify);
  Inc(yOffset, 30);

  { 1. OXYGEN LEVEL }
  if GameState.Station.Stats.OxygenLevel > 50 then StatColor := C_TEXT
  else if GameState.Station.Stats.OxygenLevel > 20 then StatColor := C_WARN
  else
  begin
    { Efek Blinking jika kritis }
    if IsBlink then StatColor := C_CRIT else StatColor := C_OFF;
  end;

  sText := Format('OXYGEN LEVEL : %3.0f%%', [GameState.Station.Stats.OxygenLevel]);
  ABitmap.TextOut(Bounds.Left + 10, yOffset, sText, StatColor, taLeftJustify);
  DrawProgressBar(ABitmap, Rect(Bounds.Left + 10, yOffset + 20, Bounds.Right - 10, yOffset + 35),
                  GameState.Station.Stats.OxygenLevel, 100.0, StatColor);
  Inc(yOffset, 45);

  { 2. POWER RESERVE }
  if GameState.Station.Stats.PowerReserve > 50 then StatColor := C_TEXT
  else if GameState.Station.Stats.PowerReserve > 20 then StatColor := C_WARN
  else
  begin
    if IsBlink then StatColor := C_CRIT else StatColor := C_OFF;
  end;

  sText := Format('POWER RESERVE: %3.0f%%', [GameState.Station.Stats.PowerReserve]);
  ABitmap.TextOut(Bounds.Left + 10, yOffset, sText, StatColor, taLeftJustify);
  DrawProgressBar(ABitmap, Rect(Bounds.Left + 10, yOffset + 20, Bounds.Right - 10, yOffset + 35),
                  GameState.Station.Stats.PowerReserve, 100.0, StatColor);

  if GameState.Station.Stats.PowerConsumption > GameState.Station.Stats.TotalPowerOutput then
  begin
    { Efek berkedip untuk peringatan draining }
    if IsBlink then
      ABitmap.TextOut(Bounds.Left + 10, yOffset + 38, '! DRAINING !', C_WARN, taLeftJustify)
    else
      ABitmap.TextOut(Bounds.Left + 10, yOffset + 38, '! DRAINING !', C_OFF, taLeftJustify);
  end;
  Inc(yOffset, 55);

  { 3. HULL INTEGRITY }
  if GameState.Station.Stats.HullIntegrity > 50 then StatColor := C_TEXT
  else if GameState.Station.Stats.HullIntegrity > 20 then StatColor := C_WARN
  else
  begin
    if IsBlink then StatColor := C_CRIT else StatColor := C_OFF;
  end;

  sText := Format('HULL INTEGRITY: %3.0f%%', [GameState.Station.Stats.HullIntegrity]);
  ABitmap.TextOut(Bounds.Left + 10, yOffset, sText, StatColor, taLeftJustify);
  DrawProgressBar(ABitmap, Rect(Bounds.Left + 10, yOffset + 20, Bounds.Right - 10, yOffset + 35),
                  GameState.Station.Stats.HullIntegrity, 100.0, StatColor);
  Inc(yOffset, 45);

  { 4. CORE TEMPERATURE (Sistem Baru) }
  if GameState.Station.Stats.CoreTemperature >= 85 then
  begin
    if IsBlink then StatColor := C_CRIT else StatColor := C_OFF;
  end
  else if GameState.Station.Stats.CoreTemperature >= 60 then StatColor := C_WARN
  else StatColor := C_TEXT;

  sText := Format('CORE TEMP     : %3.0f%%', [GameState.Station.Stats.CoreTemperature]);
  ABitmap.TextOut(Bounds.Left + 10, yOffset, sText, StatColor, taLeftJustify);
  DrawProgressBar(ABitmap, Rect(Bounds.Left + 10, yOffset + 20, Bounds.Right - 10, yOffset + 35),
                  GameState.Station.Stats.CoreTemperature, 100.0, StatColor);

  if GameState.Station.Stats.CoreTemperature >= 85 then
  begin
    { Efek berkedip untuk peringatan overheat }
    if IsBlink then
      ABitmap.TextOut(Bounds.Left + 10, yOffset + 38, '! OVERHEAT WARNING !', C_CRIT, taLeftJustify)
    else
      ABitmap.TextOut(Bounds.Left + 10, yOffset + 38, '! OVERHEAT WARNING !', C_OFF, taLeftJustify);
  end;
  Inc(yOffset, 55);

  { 5. TECH POINTS & CREW STATUS }
  sText := Format('TECH POINTS  : %3.0f', [GameState.Station.Stats.TechPoints]);
  ABitmap.TextOut(Bounds.Left + 10, yOffset, sText, C_TEXT, taLeftJustify);
  Inc(yOffset, 20);

  if GameState.Station.Stats.IdleCrew > 0 then StatColor := C_TEXT else StatColor := C_WARN;
  sText := Format('IDLE CREW    : %d / %d', [GameState.Station.Stats.IdleCrew, GameState.Station.Stats.TotalCrew]);
  ABitmap.TextOut(Bounds.Left + 10, yOffset, sText, StatColor, taLeftJustify);
  Inc(yOffset, 20);

  { ================================================================= }
  { 6. CHART GRAFIK NAIK TURUN DENGAN EFEK EKG (SYSTEM TRACE)         }
  { ================================================================= }

  ChartRect := Rect(Bounds.Left + 10, yOffset, Bounds.Right - 10, Bounds.Bottom - 10);

  { Latar belakang dan garis bingkai chart }
  ABitmap.FillRect(ChartRect.Left, ChartRect.Top, ChartRect.Right, ChartRect.Bottom, BGRA(0, 15, 10, 255), dmSet);
  ABitmap.Rectangle(ChartRect.Left, ChartRect.Top, ChartRect.Right, ChartRect.Bottom, C_GRID, BGRA(0,0,0,0), dmSet);

  { Garis Grid (Crosshair pudar di tengah) }
  ABitmap.DrawLineAntialias(ChartRect.Left, ChartRect.Top + (ChartRect.Bottom - ChartRect.Top) div 2,
                            ChartRect.Right, ChartRect.Top + (ChartRect.Bottom - ChartRect.Top) div 2, C_GRID, 1.0);
  ABitmap.DrawLineAntialias(ChartRect.Left + (ChartRect.Right - ChartRect.Left) div 2, ChartRect.Top,
                            ChartRect.Left + (ChartRect.Right - ChartRect.Left) div 2, ChartRect.Bottom, C_GRID, 1.0);

  { Hitung Indeks Stress Stasiun (Kombinasi Suhu Inti & Kerusakan Lambung) }
  Stress := (GameState.Station.Stats.CoreTemperature / 100.0) + ((100.0 - GameState.Station.Stats.HullIntegrity) / 200.0);
  if Stress > 1.0 then Stress := 1.0;

  { Menentukan warna garis berdasarkan tingkat stress (Hijau -> Kuning -> Merah) }
  if Stress > 0.75 then ChartColor := C_CRIT
  else if Stress > 0.4 then ChartColor := C_WARN
  else ChartColor := C_TEXT;

  { Menggunakan waktu sistem aktual untuk animasi bergulir tanpa henti }
  TimeVal := Now * 86400.0;
  LastPy := -1;

  { Render Gelombang Garis (Waveform Trace) }
  for px := ChartRect.Left + 1 to ChartRect.Right - 1 do
  begin
    { Algoritma pergerakan: Gelombang semakin cepat merambat jika stress tinggi }
    WaveOffset := (px * 0.05) - (TimeVal * (3.0 + Stress * 8.0));

    { Dasar osilasi (Kombinasi 2 sinus agar bentuknya natural dan tidak kaku) }
    py := ChartRect.Top + ((ChartRect.Bottom - ChartRect.Top) div 2)
          + Round(Sin(WaveOffset) * (5.0 + Stress * 12.0))
          + Round(Cos(WaveOffset * 0.3) * (2.0 + Stress * 5.0));

    { Efek "Glitch" (Lonjakan mendadak / Spikes) jika suhu atau kerusakan memburuk }
    if (Stress > 0.2) and (Random(100) < (Stress * 30)) then
      py := py + Round((Random - 0.5) * Stress * 25.0);

    { Pembatasan (Clamp) agar garis tidak menggambar ke luar batas kotak }
    if py < ChartRect.Top + 2 then py := ChartRect.Top + 2;
    if py > ChartRect.Bottom - 2 then py := ChartRect.Bottom - 2;

    { Hubungkan titik ke titik sebelumnya }
    if LastPy <> -1 then
      ABitmap.DrawLineAntialias(px - 1, LastPy, px, py, ChartColor, 1.5);

    LastPy := py;
  end;

  { Kotak overlay judul kecil di pojok kiri atas grafik }
  ABitmap.FillRect(ChartRect.Left + 1, ChartRect.Top + 1, ChartRect.Left + 72, ChartRect.Top + 14, BGRA(0, 15, 10, 200), dmSet);
  ABitmap.FontHeight := 10;
  ABitmap.TextOut(ChartRect.Left + 4, ChartRect.Top + 1, 'CORE TRACE', C_TEXT, taLeftJustify);
end;

class procedure TPanelRenderer.RenderSystemModules(ABitmap: TBGRABitmap; Bounds: TRect; GameState: TGameStateManager; IsBlink: Boolean);
var
  yOffset: Integer;
  m: TModuleType;
  ModName, ModStatusStr, DetailStr, UpgradeCrewStr: string;
  ModColor: TBGRAPixel;
  SparkX, SparkY, k: Integer;
begin
  ABitmap.FillRect(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, C_PANEL, dmSet);
  ABitmap.Rectangle(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, C_TEXT, BGRA(0,0,0,0), dmSet);

  ABitmap.FontHeight := 14;
  yOffset := Bounds.Top + 10;

  ABitmap.TextOut(Bounds.Left + 10, yOffset, '[ L ] SYSTEM MODULES', C_TEXT, taLeftJustify);
  Inc(yOffset, 30);

  for m := Low(TModuleType) to High(TModuleType) do
  begin
    case m of
      mtLifeSupport:     ModName := '> LIFE SUPPORT';
      mtDeflectorShield: ModName := '> DEFLECTOR SHIELD';
      mtResearchLab:     ModName := '> RESEARCH LAB';
      mtCommsArray:      ModName := '> COMMS ARRAY';
      mtMainGenerator:   ModName := '> MAIN GENERATOR';
    end;

    case GameState.Modules[m]^.Status of
      msOnline:    begin ModStatusStr := '[ON]'; ModColor := C_TEXT; end;
      msOffline:   begin ModStatusStr := '[OFF]'; ModColor := C_OFF; end;
      msDamaged:   begin
                     ModStatusStr := '[DMG]';
                     if IsBlink then ModColor := C_CRIT else ModColor := C_OFF;
                   end;
      msRepairing: begin ModStatusStr := '[REP]'; ModColor := C_WARN; end;
    end;

    { Tampilkan daya setelah memperhitungkan upgrade }
    DetailStr := Format('Pwr: %3.0f%%', [GameState.Modules[m]^.PowerDraw]);

    if GameState.Modules[m]^.Status = msRepairing then
      DetailStr := DetailStr + Format(' | Rep: %3.0f%%', [(GameState.Modules[m]^.RepairProgress / GameState.Modules[m]^.RepairTimeReq) * 100])
    else if GameState.Modules[m]^.Status = msOnline then
      DetailStr := DetailStr + ' | Sts: OK'
    else
      DetailStr := DetailStr + ' | Sts: IDLE';

    { Tampilkan Level Upgrade dan Jumlah Kru }
    UpgradeCrewStr := Format('Lvl: %d | Crew: %d', [GameState.Modules[m]^.UpgradeLevel, GameState.Modules[m]^.AssignedCrew]);

    ABitmap.TextOut(Bounds.Left + 10, yOffset, ModName, ModColor, taLeftJustify);
    ABitmap.TextOut(Bounds.Right - 10, yOffset, ModStatusStr, ModColor, taRightJustify);

    { VISUAL UX BARU: Efek Sparks/Glitch pada Modul Rusak }
    if (GameState.Modules[m]^.Status = msDamaged) and IsBlink then
    begin
      RandSeed := Integer(m) + Round(yOffset);
      for k := 1 to 3 do
      begin
        SparkX := Bounds.Right - 55 - Random(30);
        SparkY := yOffset + Random(12);
        ABitmap.FillRect(SparkX, SparkY, SparkX + 3, SparkY + 2, C_WARN, dmSet);
      end;
    end;

    ABitmap.FontHeight := 10;
    ABitmap.TextOut(Bounds.Left + 25, yOffset + 15, DetailStr, C_OFF, taLeftJustify);

    { Gambar info upgrade & kru di sebelah kanan }
    ABitmap.TextOut(Bounds.Right - 10, yOffset + 15, UpgradeCrewStr, C_OFF, taRightJustify);
    ABitmap.FontHeight := 14;

    Inc(yOffset, 35);
  end;
end;

end.
