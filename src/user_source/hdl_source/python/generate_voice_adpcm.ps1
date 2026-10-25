param(
    [Parameter(Mandatory=$true)][string[]]$InputWav,
    [Parameter(Mandatory=$true)][string]$OutputDir,
    [Parameter(Mandatory=$true)][string]$VerilogOut
)

$ErrorActionPreference = 'Stop'
if ($InputWav.Count -ne 4) { throw 'Exactly four WAV files are required.' }

$stepTable = [int[]](
    7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,
    34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,
    157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,
    724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,
    3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,
    15289,16818,18500,20350,22385,24623,27086,29794,32767)
$indexTable = [int[]](-1,-1,-1,-1,2,4,6,8)

function Read-WavMono16([string]$Path) {
    $fs = [IO.File]::OpenRead($Path)
    $br = [IO.BinaryReader]::new($fs)
    try {
        if ([Text.Encoding]::ASCII.GetString($br.ReadBytes(4)) -ne 'RIFF') { throw "$Path is not RIFF" }
        [void]$br.ReadUInt32()
        if ([Text.Encoding]::ASCII.GetString($br.ReadBytes(4)) -ne 'WAVE') { throw "$Path is not WAVE" }
        $channels = 0; $rate = 0; $bits = 0; $format = 0; $raw = $null
        while ($fs.Position -lt $fs.Length) {
            $id = [Text.Encoding]::ASCII.GetString($br.ReadBytes(4))
            if ($fs.Position + 4 -gt $fs.Length) { break }
            $len = [int]$br.ReadUInt32()
            if ($id -eq 'fmt ') {
                $format = $br.ReadUInt16(); $channels = $br.ReadUInt16(); $rate = $br.ReadUInt32()
                [void]$br.ReadUInt32(); [void]$br.ReadUInt16(); $bits = $br.ReadUInt16()
                if ($len -gt 16) { [void]$br.ReadBytes($len - 16) }
            } elseif ($id -eq 'data') {
                $raw = $br.ReadBytes($len)
            } else {
                [void]$br.ReadBytes($len)
            }
            if (($len -band 1) -ne 0) { [void]$br.ReadByte() }
        }
        if ($format -ne 1 -or $channels -ne 1 -or $rate -ne 48000 -or $bits -ne 16) {
            throw "$Path must be PCM mono 48000 Hz 16-bit (got format=$format channels=$channels rate=$rate bits=$bits)"
        }
        $count = [int]($raw.Length / 2)
        $samples = [int16[]]::new($count)
        [Buffer]::BlockCopy($raw, 0, $samples, 0, $raw.Length)
        return $samples
    } finally { $br.Dispose(); $fs.Dispose() }
}

function Convert-To8kCompressed([int16[]]$Source) {
    $n = [int][math]::Floor($Source.Length / 6)
    $x = [double[]]::new($n)
    $peak = 0.0
    for ($i=0; $i -lt $n; $i++) {
        $sum = 0.0
        for ($j=0; $j -lt 6; $j++) { $sum += $Source[$i*6+$j] }
        $x[$i] = $sum / 6.0
        $a = [math]::Abs($x[$i]); if ($a -gt $peak) { $peak = $a }
    }
    if ($peak -lt 1.0) { return [int16[]]::new($n) }
    for ($i=0; $i -lt $n; $i++) { $x[$i] /= $peak }

    # A gentle 20 ms compressor.  The previous 10x AGC made room noise almost
    # as loud as speech before 4-bit encoding, which produced strong hiss.
    # A soft RMS noise gate suppresses true pauses without clipping syllables.
    $sqPrefix = [double[]]::new($n + 1)
    for ($i=0; $i -lt $n; $i++) { $sqPrefix[$i+1] = $sqPrefix[$i] + $x[$i]*$x[$i] }
    $y = [double[]]::new($n)
    $gainSmooth = 1.0
    $outPeak = 0.0
    for ($i=0; $i -lt $n; $i++) {
        $lo = [math]::Max(0, $i-80); $hi = [math]::Min($n, $i+80)
        $env = [math]::Sqrt(($sqPrefix[$hi]-$sqPrefix[$lo]) / [math]::Max(1,$hi-$lo))
        $gain = [math]::Min(3.0, 0.11 / [math]::Max($env,1e-9))
        $gainSmooth = 0.02*$gain + 0.98*$gainSmooth
        if ($env -le 0.002) { $gate = 0.0 }
        elseif ($env -ge 0.012) { $gate = 1.0 }
        else { $gate = ($env - 0.002) / 0.010 }
        $y[$i] = $x[$i] * $gainSmooth * $gate
        $a = [math]::Abs($y[$i]); if ($a -gt $outPeak) { $outPeak = $a }
    }
    $out = [int16[]]::new($n)
    # 75% peak leaves headroom for the HDMI/I2S path and reduces quantization
    # noise and speaker distortion compared with the old 95% normalization.
    $scale = if ($outPeak -gt 0) { 24576.0/$outPeak } else { 0.0 }
    for ($i=0; $i -lt $n; $i++) {
        $v = [math]::Round($y[$i]*$scale)
        $out[$i] = [int16][math]::Max(-32768,[math]::Min(32767,$v))
    }
    return $out
}

function Encode-Ima([int16[]]$Pcm) {
    $codes = [byte[]]::new($Pcm.Length)
    $pred = 0; $idx = 0
    for ($i=0; $i -lt $Pcm.Length; $i++) {
        $step = $stepTable[$idx]
        $diff = [int]$Pcm[$i] - $pred
        $code = 0
        if ($diff -lt 0) { $code = 8; $diff = -$diff }
        $delta = $step -shr 3
        if ($diff -ge $step) { $code = $code -bor 4; $diff -= $step; $delta += $step }
        if ($diff -ge ($step -shr 1)) { $code = $code -bor 2; $diff -= ($step -shr 1); $delta += ($step -shr 1) }
        if ($diff -ge ($step -shr 2)) { $code = $code -bor 1; $delta += ($step -shr 2) }
        if (($code -band 8) -ne 0) { $pred -= $delta } else { $pred += $delta }
        $pred = [math]::Max(-32768,[math]::Min(32767,$pred))
        $idx += $indexTable[$code -band 7]
        $idx = [math]::Max(0,[math]::Min(88,$idx))
        $codes[$i] = [byte]$code
    }
    return $codes
}

function Decode-Ima([byte[]]$Codes) {
    $pcm = [int16[]]::new($Codes.Length)
    $pred = 0; $idx = 0
    for ($i=0; $i -lt $Codes.Length; $i++) {
        $code = [int]$Codes[$i]; $step = $stepTable[$idx]
        $delta = $step -shr 3
        if (($code -band 4) -ne 0) { $delta += $step }
        if (($code -band 2) -ne 0) { $delta += ($step -shr 1) }
        if (($code -band 1) -ne 0) { $delta += ($step -shr 2) }
        if (($code -band 8) -ne 0) { $pred -= $delta } else { $pred += $delta }
        $pred = [math]::Max(-32768,[math]::Min(32767,$pred))
        $idx += $indexTable[$code -band 7]
        $idx = [math]::Max(0,[math]::Min(88,$idx))
        $pcm[$i] = [int16]$pred
    }
    return $pcm
}

function Write-Wav16([string]$Path,[int16[]]$Samples) {
    $fs=[IO.File]::Create($Path); $bw=[IO.BinaryWriter]::new($fs)
    try {
        $bytes=$Samples.Length*2
        $bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $bw.Write([uint32](36+$bytes))
        $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $bw.Write([uint32]16)
        $bw.Write([uint16]1); $bw.Write([uint16]1); $bw.Write([uint32]8000)
        $bw.Write([uint32]16000); $bw.Write([uint16]2); $bw.Write([uint16]16)
        $bw.Write([Text.Encoding]::ASCII.GetBytes('data')); $bw.Write([uint32]$bytes)
        foreach($s in $Samples){$bw.Write($s)}
    } finally {$bw.Dispose();$fs.Dispose()}
}

function Write-Mif([string]$Path,[byte[]]$Codes,[int]$Start,[int]$Depth,[bool]$PackPairs) {
    $sw=[IO.StreamWriter]::new($Path,$false,[Text.Encoding]::ASCII)
    try {
        $width=if($PackPairs){8}else{4}
        $sw.WriteLine("WIDTH=$width;"); $sw.WriteLine("DEPTH=$Depth;"); $sw.WriteLine()
        $sw.WriteLine('ADDRESS_RADIX=UNS;'); $sw.WriteLine('DATA_RADIX=HEX;'); $sw.WriteLine()
        $sw.WriteLine('CONTENT BEGIN')
        for($i=0;$i-lt$Depth;$i++){
            if($PackPairs){
                $src=$Start+2*$i
                $lo=if($src-lt$Codes.Length){$Codes[$src]}else{0}
                $hi=if(($src+1)-lt$Codes.Length){$Codes[$src+1]}else{0}
                $v=$lo-bor($hi-shl4); $hex=$v.ToString('X2')
            } else {
                $src=$Start+$i; $v=if($src-lt$Codes.Length){$Codes[$src]}else{0}; $hex=$v.ToString('X1')
            }
            $sw.WriteLine("$i : $hex;" )
        }
        $sw.WriteLine('END;')
    } finally {$sw.Dispose()}
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$voices=@(); $manifest=@()
for($v=0;$v-lt3;$v++){
    $pcm=Convert-To8kCompressed (Read-WavMono16 $InputWav[$v])
    $codes=Encode-Ima $pcm
    Write-Wav16 (Join-Path $OutputDir "voice$($v+1)_preview_8k_adpcm.wav") (Decode-Ima $codes)
    $sampleDepth=if($v-lt2){2048}else{8192}
    $memDepth=if($v-lt2){2048}else{4096}
    $width=if($v-lt2){4}else{8}
    $impl=if($v-lt2){'9K'}else{'32K'}
    $banks=[int][math]::Ceiling($codes.Length/$sampleDepth)
    for($b=0;$b-lt$banks;$b++){
        $name=('img{0}_b{1:D2}.mif' -f ($v+1),$b)
        Write-Mif (Join-Path $OutputDir $name) $codes ($b*$sampleDepth) $memDepth ($v-ge2)
    }
    $voices += [pscustomobject]@{Index=$v;Samples=$codes.Length;SampleDepth=$sampleDepth;MemDepth=$memDepth;Width=$width;Impl=$impl;Banks=$banks}
    $manifest += "image$($v+1): $($codes.Length) samples, $([math]::Round($codes.Length/8000,4)) s, $banks x $impl"
}
$manifest += 'image4: 25048 samples, 3.131 s, 7 x 32K, original 8-bit PCM'
$manifest | Set-Content -LiteralPath (Join-Path $OutputDir 'manifest.txt') -Encoding ASCII

$sb=[Text.StringBuilder]::new()
[void]$sb.AppendLine('// Auto-generated image 1-3, 4-bit IMA-ADPCM voice ROM bank.')
[void]$sb.AppendLine('module voice_adpcm_rom(input wire clk, input wire [1:0] voice_sel, input wire [14:0] addr, output reg [3:0] dout);')
foreach($v in $voices){
    for($b=0;$b-lt$v.Banks;$b++){
        $wire="v$($v.Index)b$b"; $aw=if($v.MemDepth-eq2048){11}else{12}; $slice=if($v.MemDepth-eq2048){'addr[10:0]'}else{'addr[12:1]'}
        [void]$sb.AppendLine("wire [$($v.Width-1):0] $wire;")
        [void]$sb.AppendLine("EG_LOGIC_BRAM #(.DATA_WIDTH_A($($v.Width)),.ADDR_WIDTH_A($aw),.DATA_DEPTH_A($($v.MemDepth)),.DATA_WIDTH_B($($v.Width)),.ADDR_WIDTH_B($aw),.DATA_DEPTH_B($($v.MemDepth)),.MODE(`"SP`"),.REGMODE_A(`"NOREG`"),.IMPLEMENT(`"$($v.Impl)`"),.DEBUGGABLE(`"NO`"),.PACKABLE(`"NO`"),.INIT_FILE(`"python/voice_adpcm/img$($v.Index+1)_b$($b.ToString('00')).mif`"),.FILL_ALL(`"NONE`")) u_v$($v.Index)_b$b (.dia($($v.Width)'d0),.dib($($v.Width)'d0),.addra($slice),.addrb($aw'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa($wire),.dob());")
    }
}
[void]$sb.AppendLine('always @* begin')
[void]$sb.AppendLine("  dout = 4'd0;")
[void]$sb.AppendLine('  case (voice_sel)')
foreach($v in $voices){
    $bankSel=if($v.SampleDepth-eq2048){'addr[14:11]'}else{'addr[14:13]'}
    [void]$sb.AppendLine("    2'd$($v.Index): case ($bankSel)")
    for($b=0;$b-lt$v.Banks;$b++){
        $rhs=if($v.Width-eq4){"v$($v.Index)b$b"}else{('addr[0] ? v{0}b{1}[7:4] : v{0}b{1}[3:0]' -f $v.Index,$b)}
        [void]$sb.AppendLine("      $b`: dout = $rhs;")
    }
    [void]$sb.AppendLine("      default: dout = 4'd0; endcase")
}
[void]$sb.AppendLine("    default: dout = 4'd0;")
[void]$sb.AppendLine('  endcase')
[void]$sb.AppendLine('end')
[void]$sb.AppendLine('endmodule')
[IO.File]::WriteAllText($VerilogOut,$sb.ToString(),[Text.Encoding]::ASCII)

$voices | Format-Table Index,Samples,SampleDepth,MemDepth,Width,Impl,Banks -AutoSize
