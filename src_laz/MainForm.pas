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

    // Read FriendlyName
    varName := Unassigned;
    if PropBag.Read('FriendlyName', varName, nil) <> S_OK then
    begin
      PropBag := nil;
      Moniker := nil;
      Continue;
    end;

    cboCameras.Items.Add(VarToStr(varName));

    // Store Moniker directly in array for later use
    SetLength(FMonikers, count + 1);
    FMonikers[count] := Moniker;
    Inc(count);

    PropBag := nil;
  end;

  if cboCameras.Items.Count = 0 then
    cboCameras.Items.Add('(no camera detected)');
  cboCameras.ItemIndex := 0;
end;

procedure TfrmMain.StartPreview(CameraIndex: Integer);
const
  // Hardcoded original Microsoft GUID for IBaseFilter to prevent header translation errors
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

  // 1. Create BindContext (fallback, some drivers require it)
  if CreateBindCtx(0, BindCtx) <> S_OK then
    BindCtx := nil;

  // 2. Request IUnknown (bypass FPC header bugs)
  hr := FMonikers[CameraIndex].BindToObject(BindCtx, nil, IID_IUnknown, Unk);
  if Failed(hr) or (Unk = nil) then
  begin
    ShowMessage('Error binding camera (IUnknown): 0x' + IntToHex(Cardinal(hr), 8));
    Exit;
  end;

  // 3. Type-safe cast with explicit GUID using Supports()
  if not Supports(Unk, REAL_IID_IBaseFilter, CameraFilter) then
  begin
    ShowMessage('Error: The device rejects IBaseFilter.' + sLineBreak + sLineBreak +
                'Possible causes:' + sLineBreak +
                '1. Windows privacy settings block camera access for desktop apps.' + sLineBreak +
                '2. Architecture conflict (e.g., 32-bit app accessing a 64-bit virtual driver).' + sLineBreak +
                '3. The camera is currently in use by another application.');
    Exit;
  end;

  // --- Graph building ---
  hr := CoCreateInstance(CLSID_FilterGraph, nil, CLSCTX_INPROC_SERVER,
    IID_IGraphBuilder, FGraph);
  if Failed(hr) then Exit;

  hr := CoCreateInstance(CLSID_CaptureGraphBuilder2, nil, CLSCTX_INPROC_SERVER,
    IID_ICaptureGraphBuilder2, FCapture);
  if Failed(hr) then begin StopPreview; Exit; end;

  FCapture.SetFiltergraph(FGraph);

  wName := 'Camera';
  FGraph.AddFilter(CameraFilter, PWideChar(wName));

  // Render preview pin, fallback to capture pin
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
