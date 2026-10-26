@echo off
chcp 65001 >nul
setlocal
set "SHUBIAN_ENGINE=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%SHUBIAN_ENGINE%" (
  echo 未找到 Godot，请检查 D:\Godot 下的安装。
  pause
  exit /b 1
)
echo 正在打开分片肩披试验预览，尚非最终角色美术。
start "Shubian costume study" "%SHUBIAN_ENGINE%" --path "%~dp0.." --script "res://tools/run_segmented_mantle.gd"
