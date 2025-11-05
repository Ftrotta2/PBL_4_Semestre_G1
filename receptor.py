import serial
import time
from datetime import datetime

# --- 1. CONFIGURE A PORTA COM AQUI ---
# Esta é a porta "Outgoing" do Bluetooth (ex: "COM5")
PORT = "COM3" 
# ----------------------------------

BAUD = 115200  

try:
    ser = serial.Serial(PORT, BAUD, timeout=1) 
    print(f"Conectado a {PORT}.")
    print("O LED azul no ESP32 deve parar de piscar e ficar ACESO.")
except serial.SerialException as e:
    print(f"Erro ao conectar a {PORT}: {e}")
    print("Verifique se o ESP32 esta ligado e a porta COM esta correta.")
    exit()


fname = f"HOMEFISIO_DADOS_3_SENSORES_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
print(f"Salvando dados em: {fname}")

with open(fname, "w", encoding="utf-8", newline='') as f:
    
    # Cabeçalho correto para 3 sensores
    header = "p1,r1,y1,p2,r2,y2,p3,r3,y3,t_ms\n"
    f.write(header)
    print(f"Gravando cabeçalho: {header.strip()}")
    print("Ouvindo dados... Pressione Ctrl+C para parar.")

    try:
        while True:
            try:
                line = ser.readline().decode(errors="ignore").strip()
                
                # Filtro: Só salva linhas que parecem dados (9 vírgulas para 10 colunas)
                if line and line.count(',') == 9: 
                    print(line)
                    f.write(line + "\n")
                    f.flush()
                # Opcional: mostra as mensagens de boot que foram ignoradas
                # elif line:
                #    print(f"Ignorando linha de boot/lixo: {line}")
                    
            except serial.SerialException as e:
                print(f"Erro de leitura serial: {e}. Desconectado.")
                break

    except KeyboardInterrupt:
        print("\nInterrupcao pelo usuario.")

ser.close()
print("Conexao encerrada.")
print(f"Arquivo salvo em: {fname}")