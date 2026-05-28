@echo off
chcp 65001 >nul
cd /d "E:\桌面\Desktop\py_fpga高速交易"
echo ========================================
echo  py_fpga高速交易 - 历史行情获取
echo ========================================
echo.
echo 正在获取 %date% 的历史1分钟K线...
echo 数据源: akshare(东方财富) / 东方财富直连 / 新浪
echo.
echo 提示: 如果当前是非交易时段（凌晨/周末），
echo       程序会自动等待到开盘时间后再拉取。
echo.
echo 按 Ctrl+C 可随时退出
echo.
python -X utf8 -u fetch_history.py %*
echo.
echo -------------------------------------------------
echo  完成！按任意键退出...
pause >nul
