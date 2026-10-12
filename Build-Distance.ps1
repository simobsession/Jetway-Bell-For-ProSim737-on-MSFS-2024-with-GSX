param([string]$SdkRoot = $env:MSFS2024_SDK_ROOT)
$ErrorActionPreference='Stop'
if (-not $SdkRoot) { throw 'Set MSFS2024_SDK_ROOT or pass -SdkRoot with your official MSFS 2024 SDK directory.' }
$taskSdk=$SdkRoot
$taskWasm=Join-Path $taskSdk 'WASM'
$taskObject=Join-Path $PSScriptRoot 'build-tools\JetwayDistance.o'
$taskOutput=Join-Path $PSScriptRoot 'JetwayDistance.wasm'
New-Item -ItemType Directory -Path (Split-Path $taskOutput) -Force | Out-Null
& "$taskWasm\llvm\bin\clang-cl.exe" /c /GS- /clang:-O3 /clang:-std=c++17 --target=wasm32-unknown-wasi "/clang:--sysroot=$taskWasm\wasi-sysroot" /clang:-fstack-size-section /clang:-ffunction-sections /clang:-fdata-sections /clang:-fvisibility=hidden /clang:-fno-exceptions /clang:-fno-stack-protector /clang:-fms-extensions /clang:-mbulk-memory /D_WASM /D__wasi__ "/I$taskWasm\include" "/I$taskSdk\SimConnect SDK\include" "/I$taskWasm\wasi-sysroot\include\c++\v1" "/Fo$taskObject" "$PSScriptRoot\JetwayDistance.cpp"
if($LASTEXITCODE -ne 0){throw 'C++ compilation failed'}
& "$taskWasm\llvm\bin\wasm-ld.exe" --no-entry --stack-guard-page --allow-undefined --export-dynamic --export-table --export malloc --export free --export __wasm_call_ctors --export mallinfo --export mchunkit_begin --export mchunkit_next --export get_pages_state --export mark_decommit_pages --strip-debug --gc-sections -O3 --lto-O3 -L "$taskWasm\wasi-sysroot\lib\wasm32-wasi" $taskObject -lc++ -lc++abi -lc "$taskWasm\wasi-sysroot\lib\wasm32-wasi\libclang_rt.builtins-wasm32.a" "$taskWasm\WasmVersions\MSFS_WasmVersions.a" --export GetSimConnectVersion --export GetExtensionVersion --export GetExtensionVersionBuffer -o $taskOutput
if($LASTEXITCODE -ne 0){throw 'WASM linking failed'}
Get-Item $taskOutput | Select-Object Name,Length
