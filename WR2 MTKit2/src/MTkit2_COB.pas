unit MTkit2_COB;
interface
uses
  KM_Vertexes;


type
  TCOBHead = record
    VerticeCount, PolyCount: Integer;
    X, Y, Z, Xmin, Xmax, Ymin, Ymax, Zmin, ZMax: Single;
  end;

  TModelCOB = class
  public
    Head: TCOBHead;
    Vertices: array of TKMVertex3;
    Faces: array of array [1..3] of Word;
    Normals: array of TKMVertex3;

    procedure Clear;
    function LoadCOB(const aFilename: string): Boolean;
    procedure SaveCOB(const aFilename: string);
    procedure ExportLWO(const aFilename: string);
    procedure ImportLWO(const aFilename: string);
    procedure RebuildBounds;
  end;


implementation
uses
  Classes, Math, SysUtils, KM_IoModelLWO;


procedure TModelCOB.Clear;
begin
  FillChar(Head, SizeOf(Head), #0);
  SetLength(Vertices, 0);
  SetLength(Faces, 0);
  SetLength(Normals, 0);
end;


function TModelCOB.LoadCOB(const aFilename: string): Boolean;
var
  ms: TMemoryStream;
begin
  Result := False;
  if not FileExists(aFilename) then Exit;

  ms := TMemoryStream.Create;
  try
    ms.LoadFromFile(aFilename);

    ms.Read(Head, 44);

    SetLength(Vertices, Head.VerticeCount);
    SetLength(Faces, Head.PolyCount);
    SetLength(Normals, Head.PolyCount);

    ms.Read(Vertices[0], SizeOf(Vertices[0]) * Head.VerticeCount);
    ms.Read(Faces[0], SizeOf(Faces[0]) * Head.PolyCount);
    ms.Read(Normals[0], SizeOf(Normals[0]) * Head.PolyCount);
  finally
    ms.Free;
  end;

  Result := True;
end;


procedure TModelCOB.SaveCOB(const aFilename: string);
var
  ms: TMemoryStream;
begin
  ms := TMemoryStream.Create;
  try
    ms.Write(Head, 44);

    ms.Write(Vertices[0], SizeOf(Vertices[0]) * Head.VerticeCount);
    ms.Write(Faces[0], SizeOf(Faces[0]) * Head.PolyCount);
    ms.Write(Normals[0], SizeOf(Normals[0]) * Head.PolyCount);

    ms.SaveToFile(aFilename);
  finally
    ms.Free;
  end;
end;


procedure TModelCOB.ExportLWO(const aFilename: string);
const
  EXPORT_SCALE = 0.1;
var
  lwm: TLWModel;
  lay: PLWLayer;
  I: Integer;
begin
  lwm := TLWModel.Create;
  try
    lay := lwm.LayerAdd;

    // Vertices
    lay.SetVerticeCount(Head.VerticeCount);
    for I := 0 to Head.VerticeCount - 1 do
    begin
      lay.Vertices[I].X := Vertices[I].X * EXPORT_SCALE;
      lay.Vertices[I].Y := Vertices[I].Y * EXPORT_SCALE;
      lay.Vertices[I].Z := Vertices[I].Z * EXPORT_SCALE;
    end;

    // Polys
    lay.SetPolyCount(Head.PolyCount);
    for I := 0 to Head.PolyCount - 1 do
    begin
      lay.Polys[I].VertCount := 3;
      SetLength(lay.Polys[I].Indices, 3);

      lay.Polys[I].Indices[0] := Faces[I,1];
      lay.Polys[I].Indices[1] := Faces[I,2];
      lay.Polys[I].Indices[2] := Faces[I,3];

      lay.Polys[I].PolySurf := 0;
    end;

    // COB is a simple shape, it does not need a surface or anything

    lwm.SaveToFile(aFilename);
  finally
    lwm.Free;
  end;
end;


procedure TModelCOB.RebuildBounds;
var
  I: Integer;
begin
  // Normal to every polygon
  for I := 0 to Head.PolyCount - 1 do
  begin
    Normals[I] := VectorCrossProduct(@Vertices[Faces[I,1]], @Vertices[Faces[I,2]], @Vertices[Faces[I,3]]);
    Normals[I] := Normals[I].GetNormalize;
  end;

  // Bounding box
  Head.Xmin := 0; Head.Xmax := 0;
  Head.Ymin := 0; Head.Ymax := 0;
  Head.Zmin := 0; Head.Zmax := 0;
  for I := 0 to Head.VerticeCount - 1 do
  begin
    Head.Xmax := Max(Head.Xmax, Vertices[I].X);
    Head.Ymax := Max(Head.Ymax, Vertices[I].Y);
    Head.Zmax := Max(Head.Zmax, Vertices[I].Z);
    Head.Xmin := Min(Head.Xmin, Vertices[I].X);
    Head.Ymin := Min(Head.Ymin, Vertices[I].Y);
    Head.Zmin := Min(Head.Zmin, Vertices[I].Z);
  end;

  Head.X := 0; // Xmax + Xmin;
  Head.Y := 0; // Ymax + Ymin;
  Head.Z := 0; // Zmax + Zmin;
end;


procedure TModelCOB.ImportLWO(const aFilename: string);
var
  lwm: TLWModel;
  lay: TLWLayer;
  I, K: Integer;
begin
  lwm := TLWModel.Create;
  try
    lwm.LoadFromFile(aFilename);

    if lwm.LayerCount <> 1 then
      raise Exception.Create('Imported LWO must have exactly one layer');

    lay := lwm.Layers[0];

    if (lay.VerticeCount > 255) or (lay.PolyCount > 255) then
      raise Exception.Create('Can''t import more than 255 vertices or polys to COB');

    Head.VerticeCount := lay.VerticeCount;
    Head.PolyCount := lay.PolyCount;

    SetLength(Vertices, Head.VerticeCount);
    SetLength(Faces, Head.PolyCount);
    SetLength(Normals, Head.PolyCount);

    for I := 0 to lay.VerticeCount - 1 do
      Vertices[I] := lay.Vertices[I] * 10;

    for I := 0 to lay.PolyCount - 1 do
      for K := 1 to 3 do
        Faces[I, K] := lay.Polys[I].Indices[K - 1];

    RebuildBounds;
  finally
    lwm.Free;
  end;
end;


end.
