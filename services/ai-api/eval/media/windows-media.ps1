$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
function Await-Operation($Operation, $ResultType) {
    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    return $method.MakeGenericMethod($ResultType).Invoke($null, @($Operation)).GetAwaiter().GetResult()
}
try {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    if ($request.operation -eq 'synthesize') {
        $type = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
        $voice = $type::AllVoices | Where-Object Language -eq 'ko-KR' | Select-Object -First 1
        if ($null -eq $voice -or [string]::IsNullOrWhiteSpace($request.text) -or $request.text.Length -gt 2000) { throw 'invalid_request' }
        $synth = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::new()
        $synth.Voice = $voice
        $audio = Await-Operation ($synth.SynthesizeTextToStreamAsync($request.text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
        $reader = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]::new($audio)
        $null = Await-Operation ($reader.LoadAsync([uint32]$audio.Size)) ([uint32])
        $bytes = [byte[]]::new([int]$audio.Size)
        $reader.ReadBytes($bytes)
        @{ wavBase64 = [Convert]::ToBase64String($bytes); voice = $voice.DisplayName; language = $voice.Language } | ConvertTo-Json -Compress
        $reader.Dispose(); $synth.Dispose()
    } elseif ($request.operation -eq 'ocr') {
        $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime]
        $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
        $stream = [Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]::new()
        $writer = [Windows.Storage.Streams.DataWriter, Windows.Storage.Streams, ContentType = WindowsRuntime]::new($stream)
        $writer.WriteBytes([Convert]::FromBase64String($request.pngBase64))
        $null = Await-Operation ($writer.StoreAsync()) ([uint32])
        $null = $writer.DetachStream()
        $stream.Seek(0)
        $decoder = Await-Operation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
        $bitmap = Await-Operation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
        $language = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]::new('ko')
        $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
        if ($null -eq $engine) { throw 'ocr_unavailable' }
        $result = Await-Operation ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
        $words = 0
        foreach ($line in $result.Lines) { foreach ($word in $line.Words) { $words++ } }
        @{ text = $result.Text; words = $words; language = 'ko'; engine = 'Windows.Media.Ocr' } | ConvertTo-Json -Compress
        $bitmap.Dispose(); $writer.Dispose(); $stream.Dispose()
    } else { throw 'unsupported_operation' }
} catch {
    [Console]::Error.WriteLine('{"error":"windows_media_unavailable"}')
    exit 1
}
