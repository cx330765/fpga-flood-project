param(
    [Parameter(Mandatory=$true)][string]$SourceMif,
    [Parameter(Mandatory=$true)][string]$OutputDir,
    [Parameter(Mandatory=$true)][string]$VerilogOut,
    [int]$UsedSamples = 25048
)

$ErrorActionPreference = 'Stop'
$values = [System.Collections.Generic.List[byte]]::new()
foreach ($line in Get-Content -LiteralPath $SourceMif) {
    if ($line -match '^\s*\d+\s*:\s*([0-9A-Fa-f]{2})\s*;') {
        $values.Add([Convert]::ToByte($matches[1],16))
    }
}
if ($values.Count -lt $UsedSamples) { throw "Source MIF contains only $($values.Count) samples" }

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$depth = 4096
$banks = [int][math]::Ceiling($UsedSamples / $depth)
for ($bank=0; $bank -lt $banks; $bank++) {
    $path = Join-Path $OutputDir ('img4_pcm_b{0:D2}.mif' -f $bank)
    $sw = [IO.StreamWriter]::new($path,$false,[Text.Encoding]::ASCII)
    try {
        $sw.WriteLine('WIDTH=8;'); $sw.WriteLine("DEPTH=$depth;"); $sw.WriteLine()
        $sw.WriteLine('ADDRESS_RADIX=UNS;'); $sw.WriteLine('DATA_RADIX=HEX;'); $sw.WriteLine()
        $sw.WriteLine('CONTENT BEGIN')
        for ($i=0; $i -lt $depth; $i++) {
            $src = $bank*$depth+$i
            $v = if ($src -lt $UsedSamples) { $values[$src] } else { 0x80 }
            $sw.WriteLine("$i : $($v.ToString('X2'));")
        }
        $sw.WriteLine('END;')
    } finally { $sw.Dispose() }
}

# Exact PC-listenable preview of the unsigned 8-bit PCM stored in BRAM.
$preview = Join-Path $OutputDir 'voice4_preview_8k_pcm.wav'
$fs=[IO.File]::Create($preview); $bw=[IO.BinaryWriter]::new($fs)
try {
    $bytes=$UsedSamples*2
    $bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $bw.Write([uint32](36+$bytes))
    $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $bw.Write([uint32]16)
    $bw.Write([uint16]1); $bw.Write([uint16]1); $bw.Write([uint32]8000)
    $bw.Write([uint32]16000); $bw.Write([uint16]2); $bw.Write([uint16]16)
    $bw.Write([Text.Encoding]::ASCII.GetBytes('data')); $bw.Write([uint32]$bytes)
    for($i=0;$i-lt$UsedSamples;$i++){$bw.Write([int16](([int]$values[$i]-128)*256))}
} finally {$bw.Dispose();$fs.Dispose()}

$sb=[Text.StringBuilder]::new()
[void]$sb.AppendLine('// Image 4 original-quality 8-bit PCM, split across seven 32K BRAMs.')
[void]$sb.AppendLine('module voice4_pcm_rom(input wire clk, input wire [14:0] addr, output reg [7:0] dout);')
for ($bank=0; $bank -lt $banks; $bank++) {
    [void]$sb.AppendLine("wire [7:0] b$bank;")
    [void]$sb.AppendLine("EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE(`"SP`"),.REGMODE_A(`"NOREG`"),.IMPLEMENT(`"32K`"),.DEBUGGABLE(`"NO`"),.PACKABLE(`"NO`"),.INIT_FILE(`"python/voice_adpcm/img4_pcm_b$($bank.ToString('00')).mif`"),.FILL_ALL(`"NONE`")) u_b$bank (.dia(8'd0),.dib(8'd0),.addra(addr[11:0]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(b$bank),.dob());")
}
[void]$sb.AppendLine('always @* begin')
[void]$sb.AppendLine("  dout = 8'h80;")
[void]$sb.AppendLine('  case (addr[14:12])')
for ($bank=0; $bank -lt $banks; $bank++) { [void]$sb.AppendLine("    $bank`: dout = b$bank;") }
[void]$sb.AppendLine("    default: dout = 8'h80;")
[void]$sb.AppendLine('  endcase')
[void]$sb.AppendLine('end')
[void]$sb.AppendLine('endmodule')
[IO.File]::WriteAllText($VerilogOut,$sb.ToString(),[Text.Encoding]::ASCII)

Write-Host "Generated $banks PCM banks, $UsedSamples samples ($([math]::Round($UsedSamples/8000,4)) s)"
