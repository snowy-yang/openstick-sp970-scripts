import serial
import time
import sys
import threading

# 抓取所有可用串口的输出，找启动日志/shell
def reader(port_name, duration=25):
    try:
        ser = serial.Serial(port_name, 115200, timeout=1)
    except Exception as e:
        print(f"[{port_name}] 无法打开: {e}")
        return
    print(f"[{port_name}] 已打开")
    buf = b''
    t0 = time.time()
    while time.time() - t0 < duration:
        try:
            data = ser.read(4096)
        except Exception:
            break
        if data:
            buf += data
            sys.stdout.write(f"[{port_name}] " + data.decode('utf-8', 'replace'))
            sys.stdout.flush()
    ser.close()
    print(f"\n[{port_name}] 共 {len(buf)} 字节")

threads = []
for p in ['COM5', 'COM4', 'COM3']:
    t = threading.Thread(target=reader, args=(p, 25), daemon=True)
    t.start()
    threads.append(t)
for t in threads:
    t.join()
