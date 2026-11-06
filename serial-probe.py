import serial
import time
import sys

# 尝试各 COM 口，抓取是否有 Linux 控制台输出
for port_name in ['COM3', 'COM4', 'COM5']:
    try:
        ser = serial.Serial(port_name, 115200, timeout=2)
        print(f"=== {port_name} 已打开，读取 5 秒 ===")
        data = b''
        t0 = time.time()
        while time.time() - t0 < 5:
            chunk = ser.read(4096)
            if chunk:
                data += chunk
                sys.stdout.write(chunk.decode('utf-8', 'replace'))
                sys.stdout.flush()
            if b'login:' in data or b'#' in data or b'$' in data:
                print(f"\n[发现 shell 提示符]")
                break
        ser.close()
        print(f"\n--- {port_name}: 收到 {len(data)} 字节 ---")
        if len(data) > 50:
            break
    except Exception as e:
        print(f"{port_name}: {e}")
