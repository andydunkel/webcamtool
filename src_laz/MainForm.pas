unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, ActiveX, DSInterfaces; // MFInterfaces entfernt

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
    FMonikers:     array of IMoniker; // Nutzt Moniker statt IMFActivate
    FGraph:        IGraphBuilder;
    FCapture:      ICaptureGraphBuilder2;
    FMediaCtrl:    IMediaControl;
    FVideoWindow:  IVideoWindow;
    procedure EnumerateCameras;
    procedure StartPreview(CameraIndex: Integer);
    procedure StopPreview;
    procedure UpdateVideoWindowSize;
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

uses
  Windows, Variants;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  CoInitialize(nil);
  // MFStartup entfernt
  EnumerateCameras;
  if (Length(FMonikers) > 0) and chkShowPreview.Checked then
    StartPreview(0);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  StopPreview;
  SetLength(FMonikers, 0);
  // MFShutdown entfernt
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

    // FriendlyName auslesen (Anzeigename der Kamera)
    varName := Unassigned;
    if PropBag.Read('FriendlyName', varName, nil) <> S_OK then
    begin
      PropBag := nil;
      Moniker := nil;
      Continue;
    end;

    cboCameras.Items.Add(VarToStr(varName));

    // Moniker direkt im Array speichern für spätere Verwendung
    SetLength(FMonikers, count + 1);
    FMonikers[count] := Moniker;
    Inc(count);

    PropBag := nil;
    // WICHTIG: Moniker hier NICHT auf nil setzen, da die Referenz im Array benötigt wird!
  end;

  if cboCameras.Items.Count = 0 then
    cboCameras.Items.Add('(keine Kamera gefunden)');
  cboCameras.ItemIndex := 0;
end;

procedure TfrmMain.StartPreview(CameraIndex: Integer);
const
  // Hardcodierte originale Microsoft GUID für IBaseFilter, um Header-Fehler auszuschließen
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

  // 1. BindContext erstellen (als Fallback, falls der Treiber es verlangt)
  if CreateBindCtx(0, BindCtx) <> S_OK then
    BindCtx := nil;

  // 2. IUnknown anfordern (Das hat funktioniert)
  hr := FMonikers[CameraIndex].BindToObject(BindCtx, nil, IID_IUnknown, Unk);
  if Failed(hr) or (Unk = nil) then
  begin
    ShowMessage('Fehler beim Binden (IUnknown): 0x' + IntToHex(Cardinal(hr), 8));
    Exit;
  end;

  // 3. Typsicherer Cast mit expliziter GUID über die Pascal-Funktion Supports()
  if not Supports(Unk, REAL_IID_IBaseFilter, CameraFilter) then
  begin
    ShowMessage('Fehler: Das Gerät verweigert IBaseFilter.' + sLineBreak + sLineBreak +
                'Mögliche Ursachen:' + sLineBreak +
                '1. Windows-Datenschutz blockiert die Kamera für Desktop-Apps.' + sLineBreak +
                '2. Architektur-Konflikt (z.B. 32-Bit App greift auf 64-Bit virtuellen Treiber zu).' + sLineBreak +
                '3. Die Kamera wird von einem anderen Programm blockiert.');
    Exit;
  end;

  // --- Ab hier regulärer Graph-Aufbau ---
  hr := CoCreateInstance(CLSID_FilterGraph, nil, CLSCTX_INPROC_SERVER,
    IID_IGraphBuilder, FGraph);
  if Failed(hr) then Exit;

  hr := CoCreateInstance(CLSID_CaptureGraphBuilder2, nil, CLSCTX_INPROC_SERVER,
    IID_ICaptureGraphBuilder2, FCapture);
  if Failed(hr) then begin StopPreview; Exit; end;

  FCapture.SetFiltergraph(FGraph);

  wName := 'Camera';
  FGraph.AddFilter(CameraFilter, PWideChar(wName));

  // Preview Pin rendern, Fallback auf Capture Pin
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
    FVideoWindow.put_Visible(-1);  // OATRUE
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
