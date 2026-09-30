unit uRadarRenderer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Types, Math, BGRABitmap, BGRABitmapTypes,
  uGameTypes, uGameState;

type
  { TRadarRenderer bertugas menggambar animasi radar }
  TRadarRenderer = class
  private
    class function C_PANEL: TBGRAPixel; inline;
    class function C_TEXT: TBGRAPixel; inline;
    class function C_GRID: TBGRAPixel; inline;
    class function C_WARN: TBGRAPixel; inline;
    class function C_CRIT: TBGRAPixel; inline;
    class function C_OFF: TBGRAPixel; inline;
  public
    class procedure RenderRadar(ABitmap: TBGRABitmap; Bounds: TRect; GameState: TGameStateManager; RadarAngle: Double; IsBlink: Boolean; FilterMode: TVisualFilterMode);
  end;

implementation

{ Implementasi Palet Warna }
class function TRadarRenderer.C_PANEL: TBGRAPixel; begin Result := BGRA(26, 28, 35, 255); end;
class function TRadarRenderer.C_TEXT: TBGRAPixel; begin Result := BGRA(0, 255, 204, 255); end;
class function TRadarRenderer.C_GRID: TBGRAPixel; begin Result := BGRA(0, 160, 120, 255); end;
class function TRadarRenderer.C_WARN: TBGRAPixel; begin Result := BGRA(255, 179, 0, 255); end;
class function TRadarRenderer.C_CRIT: TBGRAPixel; begin Result := BGRA(255, 42, 42, 255); end;
class function TRadarRenderer.C_OFF: TBGRAPixel; begin Result := BGRA(74, 77, 89, 255); end;

class procedure TRadarRenderer.RenderRadar(ABitmap: TBGRABitmap; Bounds: TRect; GameState: TGameStateManager; RadarAngle: Double; IsBlink: Boolean; FilterMode: TVisualFilterMode);
var
  cx, cy, radius, i, j: Integer;
  SweepX, SweepY: Integer;
  sStatus: string;
  StatusColor, TrailColor: TBGRAPixel;
  BlipAngle, BlipDist, TrailDist: Double;
  BlipX, BlipY, TrailX, TrailY: Integer;
  TrailAlpha: Byte;

  { Variabel Estetika Tambahan ala Referensi }
  k: Integer;
  AngleStep, TickX1, TickY1, TickX2, TickY2: Double;
  px, py, LastPy: Integer;
  SweepTrailAngle: Double;
  TrailSweepX, TrailSweepY: Integer;

  { Variabel untuk Efek Visual Sinyal Misterius }
  EncAngle: Double;
  EncX, EncY: Integer;

  { Variabel untuk Efek Visual Lainnya }
  StarX, StarY, GlitchY, GlitchH: Integer;
  OldSeed: LongInt;
begin
  { Gambar background panel }
  ABitmap.FillRect(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, C_PANEL, dmSet);

  { --- EFEK BACKGROUND (Opsi 3: Parallax Starfield) --- }
  if (FilterMode = vfmStarfield) and Assigned(GameState) then
  begin
    OldSeed := RandSeed;
    RandSeed := 12345;

    for i := 1 to 80 do
    begin
      StarX := Bounds.Left + Random(Bounds.Right - Bounds.Left);
      StarY := Bounds.Top + Random(Bounds.Bottom - Bounds.Top);
      TrailAlpha := 80 + Round(80 * Sin((RadarAngle * 5) + i));

      if GameState.Crisis.CurrentCrisis = ctMeteorShower then
      begin
        ABitmap.DrawLineAntialias(StarX, StarY, StarX + 20, StarY + 20, BGRA(255, 255, 255, TrailAlpha), 1.5);
      end
      else
        ABitmap.FillRect(StarX, StarY, StarX + 2, StarY + 2, BGRA(255, 255, 255, TrailAlpha), dmDrawWithTransparency);
    end;

    RandSeed := OldSeed;
  end;

  { Geometri Radar }
  cx := Bounds.Left + ((Bounds.Right - Bounds.Left) div 2);
  cy := Bounds.Top + ((Bounds.Bottom - Bounds.Top) div 2) + 10;
  radius := Min((Bounds.Right - Bounds.Left) div 2, (Bounds.Bottom - Bounds.Top) div 2) - 40;

  if radius > 0 then
  begin
    { 1. Cincin konsentris radar }
    for i := 1 to 3 do
      ABitmap.EllipseAntialias(cx, cy, (radius * i) / 3, (radius * i) / 3, C_GRID, 1.2, BGRA(0,0,0,0));

    { 2. Garis crosshair tengah }
    ABitmap.DrawLineAntialias(cx - radius, cy, cx + radius, cy, C_GRID, 1.2);
    ABitmap.DrawLineAntialias(cx, cy - radius, cx, cy + radius, C_GRID, 1.2);

    { 3. Skala Tepi Luar (Outer Rim Ticks) ala Gambar Referensi }
    for k := 0 to 35 do
    begin
      AngleStep := k * (Pi / 18);
      TickX1 := cx + Round((radius - 5) * Cos(AngleStep));
      TickY1 := cy + Round((radius - 5) * Sin(AngleStep));
      TickX2 := cx + Round(radius * Cos(AngleStep));
      TickY2 := cy + Round(radius * Sin(AngleStep));
      ABitmap.DrawLineAntialias(TickX1, TickY1, TickX2, TickY2, C_TEXT, 1.5);
    end;

    { 4. Efek Pendaran Sapuan Radar (Sweep Wedge Trail) }
    for j := 1 to 10 do
    begin
      SweepTrailAngle := RadarAngle - (j * 0.04);
      TrailSweepX := cx + Round(radius * Cos(SweepTrailAngle));
      TrailSweepY := cy + Round(radius * Sin(SweepTrailAngle));
      TrailAlpha := Max(0, 120 - (j * 12));
      ABitmap.DrawLineAntialias(cx, cy, TrailSweepX, TrailSweepY, BGRA(0, 255, 204, TrailAlpha), 1.0);
    end;

    { 5. Garis Sapuan Utama (Sweep Line) yang Terang }
    SweepX := cx + Round(radius * Cos(RadarAngle));
    SweepY := cy + Round(radius * Sin(RadarAngle));
    ABitmap.DrawLineAntialias(cx, cy, SweepX, SweepY, BGRA(200, 255, 240, 255), 2.2);

    { 6. Garis Gelombang Telemetri (Waveform) di bagian bawah dalam radar }
    LastPy := 0;
    for px := cx - radius + 25 to cx + radius - 25 do
    begin
      py := cy + Round(radius * 0.45) + Round(6 * Sin((px * 0.08) + (RadarAngle * 3)));
      if px > cx - radius + 26 then
        ABitmap.DrawLineAntialias(px - 1, LastPy, px, py, BGRA(0, 180, 140, 140), 1.2);
      LastPy := py;
    end;

    { 7. Ikon Stasiun di titik pusat }
    ABitmap.FillRect(cx - 3, cy - 3, cx + 3, cy + 3, C_TEXT, dmDrawWithTransparency);

    { 8. Penanganan Anomali / Blip Target Krisis }
    if Assigned(GameState) and GameState.Crisis.IsWarning then
    begin
      BlipAngle := Pi * (Integer(GameState.Crisis.CurrentCrisis) / 2.0);
      BlipDist := radius * (GameState.Crisis.CrisisTimer / 20.0);
      if BlipDist > radius then BlipDist := radius;
      if BlipDist < 0 then BlipDist := 0;

      for j := 1 to 5 do
      begin
        TrailDist := BlipDist + (j * 8.0);
        if TrailDist <= radius then
        begin
          TrailX := cx + Round(TrailDist * Cos(BlipAngle));
          TrailY := cy + Round(TrailDist * Sin(BlipAngle));
          TrailAlpha := Max(0, 255 - (j * 40));
          TrailColor := BGRA(255, 42, 42, TrailAlpha);
          ABitmap.EllipseAntialias(TrailX, TrailY, Max(1.0, 4.0 - (j * 0.5)), Max(1.0, 4.0 - (j * 0.5)), TrailColor, 1.0, TrailColor);
        end;
      end;

      BlipX := cx + Round(BlipDist * Cos(BlipAngle));
      BlipY := cy + Round(BlipDist * Sin(BlipAngle));

      if IsBlink then
        ABitmap.EllipseAntialias(BlipX, BlipY, 5.0, 5.0, C_CRIT, 2.0, BGRA(255, 255, 255, 255))
      else
        ABitmap.EllipseAntialias(BlipX, BlipY, 4.0, 4.0, C_CRIT, 2.0, C_WARN);

      ABitmap.DrawLineAntialias(BlipX, BlipY, cx, cy, C_CRIT, 1.0);
    end;

    { 9. Penanganan Sinyal Transmisi Misterius (Deep Space Encounter) }
    if Assigned(GameState) and (GameState.Station.Data.ActiveEncounter <> etNone) then
    begin
      { Tempatkan posisi sinyal secara statis di area kuadran tertentu berdasarkan jenisnya }
      EncAngle := Pi * (1.25 + (Integer(GameState.Station.Data.ActiveEncounter) * 0.25));
      EncX := cx + Round((radius * 0.7) * Cos(EncAngle));
      EncY := cy + Round((radius * 0.7) * Sin(EncAngle));

      if IsBlink then
      begin
        ABitmap.EllipseAntialias(EncX, EncY, 7.0, 7.0, C_TEXT, 1.5, BGRA(0,0,0,0));
        ABitmap.EllipseAntialias(EncX, EncY, 3.0, 3.0, C_TEXT, 1.0, C_TEXT);
        ABitmap.TextOut(EncX + 12, EncY - 7, 'UNK_SIG', C_TEXT, taLeftJustify);
      end
      else
      begin
        ABitmap.EllipseAntialias(EncX, EncY, 3.0, 3.0, C_TEXT, 1.0, C_TEXT);
      end;
    end;
  end;

  { --- EFEK FOREGROUND (Lensa Terminal / Filter Layar Atas) --- }
  if Assigned(GameState) then
  begin
    { Filter Vignette Merah }
    if FilterMode = vfmRedAlert then
    begin
      if GameState.Crisis.CurrentCrisis <> ctNone then
      begin
        if IsBlink then TrailAlpha := 80 else TrailAlpha := 30;
        ABitmap.FillRect(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, BGRA(255, 0, 0, TrailAlpha), dmDrawWithTransparency);
      end
      else
        TrailAlpha := 20;

      ABitmap.Rectangle(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, BGRA(255, 0, 0, TrailAlpha * 2), BGRA(0,0,0,0), dmDrawWithTransparency);
      ABitmap.Rectangle(Bounds.Left+1, Bounds.Top+1, Bounds.Right-1, Bounds.Bottom-1, BGRA(255, 0, 0, TrailAlpha * 2), BGRA(0,0,0,0), dmDrawWithTransparency);
    end
    { Glitch Digital Khusus Filter Mode 1 }
    else if FilterMode = vfmCRTGlitch then
    begin
      if GameState.Crisis.CurrentCrisis <> ctNone then
      begin
        RandSeed := Round(RadarAngle * 100);
        for i := 1 to 6 do
        begin
          GlitchY := Bounds.Top + Random(Bounds.Bottom - Bounds.Top);
          GlitchH := 2 + Random(12);
          if Random(2) = 0 then
            TrailColor := BGRA(0, 255, 204, 50)
          else
            TrailColor := BGRA(255, 42, 42, 50);

          ABitmap.FillRect(Bounds.Left, GlitchY, Bounds.Right, GlitchY + GlitchH, TrailColor, dmDrawWithTransparency);
        end;
      end;
    end;
  end;

  { --- EFEK SCANLINE CRT PERMANEN (OLD TECH) --- }
  { Diterapkan ke seluruh panel radar dengan garis semi-transparan tipis }
  i := Bounds.Top;
  while i < Bounds.Bottom do
  begin
    ABitmap.DrawLineAntialias(Bounds.Left, i, Bounds.Right, i, BGRA(0, 10, 5, 50), 1.0);
    Inc(i, 3);
  end;

  { Bingkai luar utama }
  ABitmap.Rectangle(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, C_TEXT, BGRA(0,0,0,0), dmDrawWithTransparency);

  { Teks Judul & Status }
  ABitmap.FontHeight := 14;
  ABitmap.FontAntialias := True;
  ABitmap.TextOut(Bounds.Left + 10, Bounds.Top + 10, '[ C ] ORBITAL RADAR & TELEMETRY', C_TEXT, taLeftJustify);

  if Assigned(GameState) and (GameState.Crisis.CurrentCrisis <> ctNone) then
  begin
    if GameState.Crisis.IsWarning then
    begin
      sStatus := '[ \ ] SCANNING... ANOMALY DETECTED';
      if IsBlink then StatusColor := C_WARN else StatusColor := C_OFF;
    end
    else
    begin
      sStatus := '[ ! ] CRISIS IMPACT IN PROGRESS';
      if IsBlink then StatusColor := C_CRIT else StatusColor := C_OFF;
    end;
  end
  else if Assigned(GameState) and (GameState.Station.Data.ActiveEncounter <> etNone) then
  begin
    { Status teks baru untuk Sinyal Transmisi beserta hitung mundur }
    sStatus := '[ ? ] SIGNAL DETECTED : T-' + IntToStr(GameState.Station.Data.EncounterTimeLeft) + 's';
    if IsBlink then StatusColor := C_TEXT else StatusColor := C_OFF;
  end
  else
  begin
    sStatus := '[ OK ] ORBITAL SPACE CLEAR';
    StatusColor := C_TEXT;
  end;

  ABitmap.TextOut(Bounds.Left + 10, Bounds.Bottom - 25, sStatus, StatusColor, taLeftJustify);
end;

end.
