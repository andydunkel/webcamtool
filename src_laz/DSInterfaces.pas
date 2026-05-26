unit DSInterfaces;

// Minimal DirectShow COM interface declarations.
// Only what is needed for this tool - no full DirectShow library required.

{$mode objfpc}{$H+}

interface

uses
  Windows, ActiveX;

type
  OAHWND       = NativeInt;
  FILTER_STATE = LongInt;

const
  // COM class IDs
  CLSID_SystemDeviceEnum: TGUID         = '{62BE5D10-60EB-11D0-BD3B-00A0C911CE86}';
  CLSID_VideoInputDeviceCategory: TGUID = '{860BB310-5D01-11D0-BD3B-00A0C911CE86}';
  CLSID_FilterGraph: TGUID              = '{E436EBB3-524F-11CE-9F53-0020AF0BA770}';
  CLSID_CaptureGraphBuilder2: TGUID     = '{BF87B6E1-8C27-11D0-B3F0-00AA003761C5}';

  // Stream category / media type for RenderStream
  PIN_CATEGORY_PREVIEW: TGUID = '{A35FF56B-9FDA-11D0-8FDF-00C04FD9189D}';
  PIN_CATEGORY_CAPTURE: TGUID = '{FB6C4281-0353-11D1-905F-0000C0CC16BA}';
  MEDIATYPE_Video: TGUID      = '{73646976-0000-0010-8000-00AA00389B71}';

  // Interface IIDs
  IID_IUnknown: TGUID              = '{00000000-0000-0000-C000-000000000046}';
  IID_ICreateDevEnum: TGUID        = '{29840822-5B84-11D0-BD3B-00A0C911CE86}';
  IID_IPropertyBag: TGUID          = '{55272A00-42CB-11CE-8135-00AA004BB851}';
  IID_IBaseFilter: TGUID           = '{56A868A5-0AD4-11CE-B03A-0020AF0BA770}';
  IID_IGraphBuilder: TGUID         = '{56A868A9-0AD4-11CE-B03A-0020AF0BA770}';
  IID_ICaptureGraphBuilder2: TGUID = '{93E5A4E0-2D50-11D2-ABFA-00A0C9C6E38D}';
  IID_IMediaControl: TGUID         = '{56A868B1-0AD4-11CE-B03A-0020AF0BA770}';
  IID_IVideoWindow: TGUID          = '{56A868B4-0AD4-11CE-B03A-0020AF0BA770}';

type
  // Forward declarations needed for cross-references
  IBaseFilter  = interface;
  IGraphBuilder = interface;

  ICreateDevEnum = interface(IUnknown)
    ['{29840822-5B84-11D0-BD3B-00A0C911CE86}']
    function CreateClassEnumerator(const clsidDeviceClass: TGUID;
      out ppEnumMoniker: IEnumMoniker; dwFlags: DWORD): HResult; stdcall;
  end;

  // Vtable must include all ancestor methods in correct order:
  // IUnknown -> IPersist -> IMediaFilter -> IBaseFilter
  IBaseFilter = interface(IUnknown)
    ['{56A868A5-0AD4-11CE-B03A-0020AF0BA770}']
    function GetClassID(out pClassID: TGUID): HResult; stdcall;              // IPersist
    function Stop: HResult; stdcall;                                          // IMediaFilter
    function Pause: HResult; stdcall;
    function Run(tStart: Int64): HResult; stdcall;
    function GetState(dwMilliSecsTimeout: DWORD; out State: FILTER_STATE): HResult; stdcall;
    function SetSyncSource(pClock: IUnknown): HResult; stdcall;
    function GetSyncSource(out pClock: IUnknown): HResult; stdcall;
    function EnumPins(out ppEnum: IUnknown): HResult; stdcall;               // IBaseFilter
    function FindPin(Id: PWideChar; out ppPin: IUnknown): HResult; stdcall;
    function QueryFilterInfo(pInfo: Pointer): HResult; stdcall;
    function JoinFilterGraph(pGraph: IUnknown; pName: PWideChar): HResult; stdcall;
    function QueryVendorInfo(out pVendorInfo: PWideChar): HResult; stdcall;
  end;

  // Vtable: IUnknown -> IFilterGraph -> IGraphBuilder
  IGraphBuilder = interface(IUnknown)
    ['{56A868A9-0AD4-11CE-B03A-0020AF0BA770}']
    function AddFilter(pFilter: IBaseFilter; pName: PWideChar): HResult; stdcall;  // IFilterGraph
    function RemoveFilter(pFilter: IBaseFilter): HResult; stdcall;
    function EnumFilters(out ppEnum: IUnknown): HResult; stdcall;
    function FindFilterByName(pName: PWideChar; out ppFilter: IBaseFilter): HResult; stdcall;
    function ConnectDirect(ppinOut: IUnknown; ppinIn: IUnknown; pmt: Pointer): HResult; stdcall;
    function Reconnect(ppin: IUnknown): HResult; stdcall;
    function Disconnect(ppin: IUnknown): HResult; stdcall;
    function SetDefaultSyncSource: HResult; stdcall;
    function Connect(ppinOut: IUnknown; ppinIn: IUnknown): HResult; stdcall; // IGraphBuilder
    function Render(ppinOut: IUnknown): HResult; stdcall;
    function RenderFile(lpcwstrFile: PWideChar; lpcwstrPlayList: PWideChar): HResult; stdcall;
    function AddSourceFilter(lpcwstrFileName: PWideChar; lpcwstrFilterName: PWideChar;
      out ppFilter: IBaseFilter): HResult; stdcall;
    function SetLogFile(hFile: THandle): HResult; stdcall;
    function Abort: HResult; stdcall;
    function ShouldOperationContinue: HResult; stdcall;
  end;

  ICaptureGraphBuilder2 = interface(IUnknown)
    ['{93E5A4E0-2D50-11D2-ABFA-00A0C9C6E38D}']
    function SetFiltergraph(pfg: IGraphBuilder): HResult; stdcall;
    function GetFiltergraph(out ppfg: IGraphBuilder): HResult; stdcall;
    function SetOutputFileName(const pType: TGUID; lpstrFile: PWideChar;
      out ppf: IBaseFilter; ppSink: Pointer): HResult; stdcall;
    function FindInterface(pCategory: PGUID; pType: PGUID; pf: IBaseFilter;
      const riid: TGUID; out ppint): HResult; stdcall;
    function RenderStream(pCategory: PGUID; pType: PGUID; pSource: IUnknown;
      pIntermediate: IBaseFilter; pSink: IBaseFilter): HResult; stdcall;
    function ControlStream(pCategory: PGUID; pType: PGUID; pFilter: IBaseFilter;
      pstart: Pointer; pstop: Pointer; wStartCookie: WORD; wStopCookie: WORD): HResult; stdcall;
    function AllocCapFile(lpstr: PWideChar; dwlSize: Int64): HResult; stdcall;
    function CopyCaptureFile(lpwstrOld: PWideChar; lpwstrNew: PWideChar;
      fAllowEscAbort: Integer; pCallback: IUnknown): HResult; stdcall;
    function FindPin(pSource: IUnknown; pindir: Integer; pCategory: PGUID;
      pType: PGUID; fUnconnected: BOOL; num: Integer; out ppPin: IUnknown): HResult; stdcall;
  end;

  // IMediaControl inherits IDispatch - IDispatch methods come first in vtable
  IMediaControl = interface(IDispatch)
    ['{56A868B1-0AD4-11CE-B03A-0020AF0BA770}']
    function Run: HResult; stdcall;
    function Pause: HResult; stdcall;
    function Stop: HResult; stdcall;
    function GetState(msTimeout: LongInt; out pfs: LongInt): HResult; stdcall;
    function RenderFile(strFilename: WideString): HResult; stdcall;
    function AddSourceFilter(strFilename: WideString; out ppUnk: IDispatch): HResult; stdcall;
    function get_FilterCollection(out ppUnk: IDispatch): HResult; stdcall;
    function get_RegFilterCollection(out ppUnk: IDispatch): HResult; stdcall;
    function StopWhenReady: HResult; stdcall;
  end;

  // IVideoWindow inherits IDispatch - all 39 property methods in exact vtable order
  IVideoWindow = interface(IDispatch)
    ['{56A868B4-0AD4-11CE-B03A-0020AF0BA770}']
    function put_Caption(strCaption: WideString): HResult; stdcall;
    function get_Caption(out strCaption: WideString): HResult; stdcall;
    function put_WindowStyle(WindowStyle: LongInt): HResult; stdcall;
    function get_WindowStyle(out WindowStyle: LongInt): HResult; stdcall;
    function put_WindowStyleEx(WindowStyleEx: LongInt): HResult; stdcall;
    function get_WindowStyleEx(out WindowStyleEx: LongInt): HResult; stdcall;
    function put_AutoShow(AutoShow: LongInt): HResult; stdcall;
    function get_AutoShow(out AutoShow: LongInt): HResult; stdcall;
    function put_WindowState(WindowState: LongInt): HResult; stdcall;
    function get_WindowState(out WindowState: LongInt): HResult; stdcall;
    function put_BackgroundPalette(BackgroundPalette: LongInt): HResult; stdcall;
    function get_BackgroundPalette(out BackgroundPalette: LongInt): HResult; stdcall;
    function put_Visible(Visible: LongInt): HResult; stdcall;
    function get_Visible(out Visible: LongInt): HResult; stdcall;
    function put_Left(Left: LongInt): HResult; stdcall;
    function get_Left(out Left: LongInt): HResult; stdcall;
    function put_Width(Width: LongInt): HResult; stdcall;
    function get_Width(out Width: LongInt): HResult; stdcall;
    function put_Top(Top: LongInt): HResult; stdcall;
    function get_Top(out Top: LongInt): HResult; stdcall;
    function put_Height(Height: LongInt): HResult; stdcall;
    function get_Height(out Height: LongInt): HResult; stdcall;
    function put_Owner(Owner: OAHWND): HResult; stdcall;
    function get_Owner(out Owner: OAHWND): HResult; stdcall;
    function put_MessageDrain(Drain: OAHWND): HResult; stdcall;
    function get_MessageDrain(out Drain: OAHWND): HResult; stdcall;
    function get_BorderColor(out Color: LongInt): HResult; stdcall;
    function put_BorderColor(Color: LongInt): HResult; stdcall;
    function get_FullScreenMode(out FullScreenMode: LongInt): HResult; stdcall;
    function put_FullScreenMode(FullScreenMode: LongInt): HResult; stdcall;
    function SetWindowForeground(Focus: LongInt): HResult; stdcall;
    function NotifyOwnerMessage(hwnd: OAHWND; uMsg: LongInt; wParam: WPARAM; lParam: LPARAM): HResult; stdcall;
    function SetWindowPosition(Left, Top, Width, Height: LongInt): HResult; stdcall;
    function GetWindowPosition(out Left, Top, Width, Height: LongInt): HResult; stdcall;
    function GetMinIdealImageSize(out Width, Height: LongInt): HResult; stdcall;
    function GetMaxIdealImageSize(out Width, Height: LongInt): HResult; stdcall;
    function GetRestorePosition(out Left, Top, Width, Height: LongInt): HResult; stdcall;
    function HideCursor(HideCursor: LongInt): HResult; stdcall;
    function IsCursorHidden(out CursorHidden: LongInt): HResult; stdcall;
  end;

implementation

end.
