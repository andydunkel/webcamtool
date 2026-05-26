unit MFInterfaces;

// Minimal Media Foundation declarations for camera enumeration and activation.
// Only what is needed for this tool - no full MF library required.

{$mode objfpc}{$H+}

interface

uses
  Windows, ActiveX;

const
  MF_VERSION     = DWORD($00020070);
  MFSTARTUP_FULL = DWORD(0);

  // Attribute: source type selector
  MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE: TGUID =
    '{49E2F8DA-B449-4654-B27B-C27F32A4A888}';
  // Value: video capture device
  MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID: TGUID =
    '{8AC3587A-4AE7-42D8-99E0-0A6013EEF90F}';
  // Attribute: friendly display name
  MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME: TGUID =
    '{60D0E559-52F8-4FA2-BBCE-ACDB34A8EC01}';

  IID_IMFAttributes: TGUID = '{2CD2D921-C447-44A7-A13C-4ADABFC247E3}';
  IID_IMFActivate:   TGUID = '{70AE66F2-C809-4E4F-8915-BDCB406B7993}';

  // Attribute key: device path (symbolic link) for vidcap devices
  MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK: TGUID =
    '{58D3EC3D-3E5F-4F0F-AADD-C99DCCFA3CB5}';

type
  // IMFAttributes - 30 methods in exact vtable order
  IMFAttributes = interface(IUnknown)
    ['{2CD2D921-C447-44A7-A13C-4ADABFC247E3}']
    function GetItem(const guidKey: TGUID;
      pValue: Pointer): HResult; stdcall;
    function GetItemType(const guidKey: TGUID;
      out pType: LongWord): HResult; stdcall;
    function CompareItem(const guidKey: TGUID;
      pValue: Pointer; out pbResult: BOOL): HResult; stdcall;
    function Compare(pTheirs: IUnknown; matchType: LongInt;
      out pbResult: BOOL): HResult; stdcall;
    function GetUINT32(const guidKey: TGUID;
      out punValue: LongWord): HResult; stdcall;
    function GetUINT64(const guidKey: TGUID;
      out punValue: QWord): HResult; stdcall;
    function GetDouble(const guidKey: TGUID;
      out pfValue: Double): HResult; stdcall;
    function GetGUID(const guidKey: TGUID;
      out pguidValue: TGUID): HResult; stdcall;
    function GetStringLength(const guidKey: TGUID;
      out pcchLength: LongWord): HResult; stdcall;
    function GetString(const guidKey: TGUID; pwszValue: PWideChar;
      cchBufSize: LongWord; out pcchLength: LongWord): HResult; stdcall;
    function GetAllocatedString(const guidKey: TGUID;
      out ppwszValue: PWideChar; out pcchLength: LongWord): HResult; stdcall;
    function GetBlobSize(const guidKey: TGUID;
      out pcbBlobSize: LongWord): HResult; stdcall;
    function GetBlob(const guidKey: TGUID; pBuf: PByte;
      cbBufSize: LongWord; out pcbBlobSize: LongWord): HResult; stdcall;
    function GetAllocatedBlob(const guidKey: TGUID;
      out ppBuf: PByte; out pcbSize: LongWord): HResult; stdcall;
    function GetUnknown(const guidKey: TGUID;
      const riid: TGUID; out ppv): HResult; stdcall;
    function SetItem(const guidKey: TGUID;
      pValue: Pointer): HResult; stdcall;
    function DeleteItem(const guidKey: TGUID): HResult; stdcall;
    function DeleteAllItems: HResult; stdcall;
    function SetUINT32(const guidKey: TGUID;
      unValue: LongWord): HResult; stdcall;
    function SetUINT64(const guidKey: TGUID;
      unValue: QWord): HResult; stdcall;
    function SetDouble(const guidKey: TGUID;
      fValue: Double): HResult; stdcall;
    function SetGUID(const guidKey: TGUID;
      const guidValue: TGUID): HResult; stdcall;
    function SetString(const guidKey: TGUID;
      wszValue: PWideChar): HResult; stdcall;
    function SetBlob(const guidKey: TGUID;
      pBuf: PByte; cbBufSize: LongWord): HResult; stdcall;
    function SetUnknown(const guidKey: TGUID;
      pUnknown: IUnknown): HResult; stdcall;
    function LockStore: HResult; stdcall;
    function UnlockStore: HResult; stdcall;
    function GetCount(out pcItems: LongWord): HResult; stdcall;
    function GetItemByIndex(unIndex: LongWord; out pguidKey: TGUID;
      pValue: Pointer): HResult; stdcall;
    function CopyAllItems(pDest: IUnknown): HResult; stdcall;
  end;

  // IMFActivate inherits IMFAttributes, adds 3 methods
  IMFActivate = interface(IMFAttributes)
    ['{70AE66F2-C809-4E4F-8915-BDCB406B7993}']
    function ActivateObject(const riid: TGUID; out ppv): HResult; stdcall;
    function ShutdownObject: HResult; stdcall;
    function DetachObject: HResult; stdcall;
  end;

function MFStartup(Version: DWORD; dwFlags: DWORD): HResult;
  stdcall; external 'mfplat.dll';
function MFShutdown: HResult;
  stdcall; external 'mfplat.dll';
function MFCreateAttributes(out ppMFAttributes: IMFAttributes;
  cInitialSize: LongWord): HResult;
  stdcall; external 'mfplat.dll';
// Returns CoTaskMem-allocated array of IMFActivate pointers via pppSourceActivate
function MFEnumDeviceSources(pAttributes: IMFAttributes;
  out pppSourceActivate: Pointer; out pcSourceActivate: LongWord): HResult;
  stdcall; external 'mf.dll';
// Creates a single IMFActivate for a specific device (identified by attributes)
function MFCreateDeviceSourceActivate(pAttributes: IMFAttributes;
  out ppActivate: IMFActivate): HResult;
  stdcall; external 'mf.dll';

implementation

end.
