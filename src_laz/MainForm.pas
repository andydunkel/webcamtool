unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, ActiveX, DSInterfaces;

type
  TfrmMain = class(TForm)
    pnlTop: TPanel;
    lblCameras: TLabel;
    cboCameras: TComboBox;
    btnSettings: TButton;
    chkShowPreview: TCheckBox;
    pnlPreview: TPanel;
    pnlBottom: TPanel;
    lblVersion: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure chkShowPreviewChange(Sender: TObject);
    procedure cboCamerasChange(Sender: TObject);
    procedure pnlPreviewResize(Sender: TObject);
  private
    FMonikers:     array of IMoniker;
    FGraph:        IGraphBuilder;
    FCapture:      ICaptureGraphBuilder2;
    FMediaCtrl:    IMediaControl;
    FVideoWindow:  IVideoWindow;
    procedure EnumerateCameras;
    procedure StartPreview(CameraIndex: Integer);
    procedure StopPreview;
    procedure UpdateVideoWindowSize;
    procedure OptimizeCameraFormat(Capture: ICaptureGraphBuilder2; Camera: IBaseFilter);
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

uses
  Windows, Variants;

const
  IID_IAMStreamConfig: TGUID = '{C6E13340-30AC-11D0-A18C-00A0C9118956}';

type
  // Fehlende DirectShow-Strukturen für das Format-Management
  PAMMediaType = ^TAMMediaType;
  TAMMediaType = record
    majortype: TGUID;
    subtype: TGUID;
    bFixedSizeSamples: BOOL;
    bTemporalCompression: BOOL;
    lSampleSize: ULONG;
    formattype: TGUID;
    pUnk: IUnknown;
    cbFormat: ULONG;
    pbFormat: Pointer;
  end;

  IAMStreamConfig = interface(IUnknown)
    ['{C6E13340-30AC-11D0-A18C-00A0C9118956}']
    function SetFormat(pmt: PAMMediaType): HResult; stdcall;
    function GetFormat(out pmt: PAMMediaType): HResult; stdcall;
    function GetNumberOfCapabilities(out piCount: Integer; out piSize: Integer): HResult; stdcall;
    function GetStreamCaps(iIndex: Integer; out ppmt: PAMMediaType; pSCC: Pointer): HResult; stdcall;
  end;

  PVideoInfoHeader = ^TVideoInfoHeader;
  TVideoInfoHeader = record
    rcSource: TRect;
    rcTarget: TRect;
    dwBitRate: DWORD;
    dwBitErrorRate: DWORD;
    AvgTimePerFrame: Int64;
    bmiHeader: TBitmapInfoHeader;
  end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  CoInitialize(nil);
  EnumerateCameras;
  if (Length(FMonikers) > 0) and chkShowPreview.Checked then
    StartPreview(0);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  StopPreview;
  SetLength(FMonikers, 0);
  CoUninitialize;
end;

procedure TfrmMain.EnumerateCameras;
var
  DevEnum:   ICreateDevEnum;
  EnumMon:   IEnumMoniker;
  Moniker:   IMoniker;
  PropBag:   IPropertyBag;
  varName:   Variant;
  Fetched:   LongWord;
  hr:        HResult;
  count:     Integer;
begin
  cboCameras.Items.Clear;
  SetLength(FMonikers, 0);
  count := 0;

  hr := CoCreateInstance(CLSID_SystemDeviceEnum, nil, CLSCTX_INPROC_SERVER,
    IID_ICreateDevEnum, DevEnum);
  if Failed(hr) then Exit;

  hr := DevEnum.CreateClassEnumerator(CLSID_VideoInputDeviceCategory, EnumMon, 0);
  if (hr <> S_OK) or (EnumMon = nil) then Exit;

  Fetched := 0;
  while EnumMon.Next(1, Moniker, Fetched) = S_OK do
  begin
    if Moniker.BindToStorage(nil, nil, IID_IPropertyBag, PropBag) <> S_OK then
    begin
      Moniker := nil;
      Continue;
    end;

    varName := Unassigned;
    if PropBag.Read('FriendlyName', varName, nil) <> S_OK then
    begin
      PropBag := nil;
      Moniker := nil;
      Continue;
    end;

    cboCameras.Items.Add(VarToStr(varName));

    SetLength(FMonikers, count + 1);
    FMonikers[count] := Moniker;
    Inc(count);

    PropBag := nil;
  end;

  if cboCameras.Items.Count = 0 then
    cboCameras.Items.Add('(no camera detected)');
  cboCameras.ItemIndex := 0;
end;

procedure TfrmMain.OptimizeCameraFormat(Capture: ICaptureGraphBuilder2; Camera: IBaseFilter);
const
  MEDIASUBTYPE_MJPG: TGUID = '{47504A4D-0000-0010-8000-00AA00389B71}';
  MEDIASUBTYPE_YUY2: TGUID = '{32595559-0000-0010-8000-00AA00389B71}';
  MEDIASUBTYPE_NV12: TGUID = '{3231564E-0000-0010-8000-00AA00389B71}';
  FORMAT_VideoInfo: TGUID  = '{05589F80-C356-11CE-BF01-00AA0055595A}';
  TARGET_WIDTH = 800; // Target width for medium resolution (e.g., 800x600 or 640x480)
var
  StreamConfig: IAMStreamConfig;
  pUnk: IUnknown;
  Count, Size: Integer;
  i: Integer;
  pmt, BestMediaType: PAMMediaType;
  SCC: array of Byte;
  VIH: PVideoInfoHeader;
  hr: HResult;
  FrameRate: Double;
  CurrentScore, BestScore: Integer;
  IsMJPEG: Boolean;
  DebugLog: TStringList;
  FormatName: String;
  BestFormatDesc: String;
begin
  if (Capture = nil) or (Camera = nil) then Exit;

  hr := Capture.FindInterface(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Video, Camera, IID_IAMStreamConfig, pUnk);
  if Failed(hr) or (pUnk = nil) then Exit;
  if not Supports(pUnk, IID_IAMStreamConfig, StreamConfig) then Exit;

  hr := StreamConfig.GetNumberOfCapabilities(Count, Size);
  if Failed(hr) or (Count = 0) then Exit;

  SetLength(SCC, Size);
  BestMediaType := nil;
  BestScore := -1;
  BestFormatDesc := 'None';

  DebugLog := TStringList.Create;
  try
    DebugLog.Add('--- Available Camera Formats ---');

    for i := 0 to Count - 1 do
    begin
      pmt := nil;
      hr := StreamConfig.GetStreamCaps(i, pmt, @SCC[0]);
      if Succeeded(hr) and (pmt <> nil) then
      begin
        if CompareMem(@pmt^.formattype, @FORMAT_VideoInfo, SizeOf(TGUID)) and (pmt^.pbFormat <> nil) then
        begin
          VIH := PVideoInfoHeader(pmt^.pbFormat);

          if VIH^.AvgTimePerFrame > 0 then
            FrameRate := 10000000.0 / VIH^.AvgTimePerFrame
          else
            FrameRate := 0;

          IsMJPEG := CompareMem(@pmt^.subtype, @MEDIASUBTYPE_MJPG, SizeOf(TGUID));

          if IsMJPEG then FormatName := 'MJPEG'
          else if CompareMem(@pmt^.subtype, @MEDIASUBTYPE_YUY2, SizeOf(TGUID)) then FormatName := 'YUY2'
          else if CompareMem(@pmt^.subtype, @MEDIASUBTYPE_NV12, SizeOf(TGUID)) then FormatName := 'NV12'
          else FormatName := 'RAW/Other';

          // --- Modified Scoring System for Medium Resolution ---
          CurrentScore := 0;

          // 1. High priority for fluid video
          if FrameRate >= 25.0 then Inc(CurrentScore, 10000);

          // 2. Priority for USB bandwidth compression
          if IsMJPEG then Inc(CurrentScore, 5000);

          // 3. Target medium resolution: Calculate penalty based on distance from TARGET_WIDTH
          // We add 4000 as a base value so the score stays positive, then subtract the difference
          Inc(CurrentScore, 4000 - Abs(VIH^.bmiHeader.biWidth - TARGET_WIDTH));

          DebugLog.Add(Format('[%3d] %-10s %4dx%-4d @ %5.1f FPS | Score: %d',
            [i, FormatName, VIH^.bmiHeader.biWidth, VIH^.bmiHeader.biHeight, FrameRate, CurrentScore]));

          // Accept only formats with >= 15 FPS
          if (FrameRate >= 15.0) and (CurrentScore > BestScore) then
          begin
            BestScore := CurrentScore;
            BestFormatDesc := Format('%s %dx%d @ %.1f FPS', [FormatName, VIH^.bmiHeader.biWidth, VIH^.bmiHeader.biHeight, FrameRate]);

            if BestMediaType <> nil then
            begin
              if BestMediaType^.pbFormat <> nil then CoTaskMemFree(BestMediaType^.pbFormat);
              if BestMediaType^.pUnk <> nil then BestMediaType^.pUnk._Release;
              CoTaskMemFree(BestMediaType);
            end;

            BestMediaType := pmt;
          end
          else
          begin
            if pmt^.pbFormat <> nil then CoTaskMemFree(pmt^.pbFormat);
            if pmt^.pUnk <> nil then pmt^.pUnk._Release;
            CoTaskMemFree(pmt);
          end;
        end
        else
        begin
          DebugLog.Add(Format('[%3d] Unsupported format type', [i]));
          if pmt^.pbFormat <> nil then CoTaskMemFree(pmt^.pbFormat);
          if pmt^.pUnk <> nil then pmt^.pUnk._Release;
          CoTaskMemFree(pmt);
        end;
      end;
    end;

    DebugLog.Add('');
    DebugLog.Add('--- Selected Format ---');
    DebugLog.Add(BestFormatDesc);

    if BestMediaType <> nil then
    begin
      hr := StreamConfig.SetFormat(BestMediaType);

      if Failed(hr) then
        DebugLog.Add('WARNING: SetFormat failed! hr = 0x' + IntToHex(Cardinal(hr), 8))
      else
        DebugLog.Add('SetFormat applied successfully.');

      if BestMediaType^.pbFormat <> nil then CoTaskMemFree(BestMediaType^.pbFormat);
      if BestMediaType^.pUnk <> nil then BestMediaType^.pUnk._Release;
      CoTaskMemFree(BestMediaType);
    end;

    DebugLog.SaveToFile(ExtractFilePath(ParamStr(0)) + 'CameraDebug.txt');

    // Debug-Meldung für die aktuelle Auswahl
    ShowMessage('Selected Camera Format: ' + BestFormatDesc + sLineBreak + sLineBreak +
                'Detailed log saved to: CameraDebug.txt');

  finally
    DebugLog.Free;
  end;
end;

procedure TfrmMain.StartPreview(CameraIndex: Integer);
const
  REAL_IID_IBaseFilter: TGUID = '{56A86895-0AD4-11CE-B03A-0020AF0BA770}';
var
  CameraFilter: IBaseFilter;
  Unk:          IUnknown;
  BindCtx:      IBindCtx;
  hr:           HResult;
  wName:        WideString;
begin
  StopPreview;
  if (CameraIndex < 0) or (CameraIndex >= Length(FMonikers)) then Exit;

  if CreateBindCtx(0, BindCtx) <> S_OK then
    BindCtx := nil;

  hr := FMonikers[CameraIndex].BindToObject(BindCtx, nil, IID_IUnknown, Unk);
  if Failed(hr) or (Unk = nil) then
  begin
    ShowMessage('Error binding camera (IUnknown): 0x' + IntToHex(Cardinal(hr), 8));
    Exit;
  end;

  if not Supports(Unk, REAL_IID_IBaseFilter, CameraFilter) then
  begin
    ShowMessage('Error: The device rejects IBaseFilter.' + sLineBreak + sLineBreak +
                'Possible causes:' + sLineBreak +
                '1. Windows privacy settings block camera access for desktop apps.' + sLineBreak +
                '2. Architecture conflict (e.g., 32-bit app accessing a 64-bit virtual driver).' + sLineBreak +
                '3. The camera is currently in use by another application.');
    Exit;
  end;

  hr := CoCreateInstance(CLSID_FilterGraph, nil, CLSCTX_INPROC_SERVER,
    IID_IGraphBuilder, FGraph);
  if Failed(hr) then Exit;

  hr := CoCreateInstance(CLSID_CaptureGraphBuilder2, nil, CLSCTX_INPROC_SERVER,
    IID_ICaptureGraphBuilder2, FCapture);
  if Failed(hr) then begin StopPreview; Exit; end;

  FCapture.SetFiltergraph(FGraph);

  wName := 'Camera';
  FGraph.AddFilter(CameraFilter, PWideChar(wName));

  OptimizeCameraFormat(FCapture, CameraFilter);

  hr := FCapture.RenderStream(@PIN_CATEGORY_PREVIEW, @MEDIATYPE_Video,
    CameraFilter, nil, nil);
  if Failed(hr) then
    hr := FCapture.RenderStream(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Video,
      CameraFilter, nil, nil);

  if Failed(hr) then begin StopPreview; Exit; end;

  FGraph.QueryInterface(IID_IVideoWindow, FVideoWindow);
  if FVideoWindow <> nil then
  begin
    FVideoWindow.put_Owner(OAHWND(pnlPreview.Handle));
    FVideoWindow.put_WindowStyle(WS_CHILD or WS_CLIPSIBLINGS or WS_CLIPCHILDREN);
    UpdateVideoWindowSize;
    FVideoWindow.put_Visible(-1);
  end;

  FGraph.QueryInterface(IID_IMediaControl, FMediaCtrl);
  if FMediaCtrl <> nil then
    FMediaCtrl.Run;
end;

procedure TfrmMain.StopPreview;
begin
  if FMediaCtrl <> nil then
    FMediaCtrl.Stop;

  if FVideoWindow <> nil then
  begin
    FVideoWindow.put_Visible(0);
    FVideoWindow.put_Owner(0);
  end;

  FVideoWindow := nil;
  FMediaCtrl   := nil;
  FCapture     := nil;
  FGraph       := nil;
end;

procedure TfrmMain.UpdateVideoWindowSize;
begin
  if FVideoWindow <> nil then
    FVideoWindow.SetWindowPosition(0, 0, pnlPreview.Width, pnlPreview.Height);
end;

procedure TfrmMain.btnSettingsClick(Sender: TObject);
begin
  ShowMessage('Settings dialog - coming soon.');
end;

procedure TfrmMain.chkShowPreviewChange(Sender: TObject);
begin
  pnlPreview.Visible := chkShowPreview.Checked;
  if chkShowPreview.Checked then
    StartPreview(cboCameras.ItemIndex)
  else
    StopPreview;
end;

procedure TfrmMain.cboCamerasChange(Sender: TObject);
begin
  if chkShowPreview.Checked then
    StartPreview(cboCameras.ItemIndex);
end;

procedure TfrmMain.pnlPreviewResize(Sender: TObject);
begin
  UpdateVideoWindowSize;
end;

end.
