import serial
from datetime import datetime

class Receptor (object):
    def __init__(self, PORT: str, BAUD: int = 115200):
        self.PORT = PORT
        self.BAUD = BAUD
        self.serial = serial.Serial()
    
    def setPORT(self, PORT: str):
        self.PORT = PORT
    def getPORT(self) -> str:
        return self.PORT
    def setBAUD(self, BAUD: str):
        self.BAUD = BAUD
    def getBAUD(self) -> str:
        return self.BAUD
    def getSerial(self) -> serial.Serial:
        return self.serial
    
    def ConectarESP32(self, time_out: int = 1):
        try:
            self.serial = serial.Serial(self.PORT, self.BAUD, timeout = time_out)
        except serial.SerialException as e:
            print(f"Erro ao conectar a {self.PORT}: {e}")
            print("Verifique se o ESP32 esta ligado e a porta COM esta correta.")
            exit()
    def CalibrarSensores(self):
        pass


class SalvarArquivo (object):
    def __init__(self, qtd_sensores: int = 3):
        self.qtd_sensores = qtd_sensores
        self.nome_arquivo = f"HOMEFISIO_DADOS_{self.qtd_sensores}_SENSORES_{datetime.now().strftime('%Y%M%d_%H%M%S')}.csv"
        self.header = ""
        self.dados = [{}]
    
    def setNomeArquivo(self, nome: str):
        self.nome_arquivo = nome
    def getNomeArquivo(self) -> str:
        return self.nome_arquivo
    def setQtdSensores(self, qtd_sensores):
        self.qtd_sensores = qtd_sensores
    def getQtdSensores(self) -> int:
        return self.qtd_sensores
    def getDados(self) -> dict:
        return self.dados
    
    def setHeader(self, header: str = ""):
        if header == "":
            for i in range(self.qtd_sensores):
                if i == 0 :
                    self.header += f"p{i+1},r{i+1},y{i+1}"
                else:
                    self.header += f",p{i+1},r{i+1},y{i+1}"
            self.header += ",t_ms\n"
        else:
            self.header = header
    def getHeader(self) -> str:
        return self.header

    def EscreverArquivo(self, receptor: Receptor):
        with open (self.nome_arquivo, "w", encoding="utf-8", newline='') as f:
            f.write(self.header)
            try:
                print("Recebendo dados... Pressione Ctrl+C para parar")
                while True:
                    try:
                        line = receptor.getSerial().readline().decode(errors="ignore").strip()
                        
                        if line and line.count(',') == self.qtd_sensores*3:
                            f.write(line + "\n")
                            f.flush()
                            
                            valores = [float(v) for v in line.split(',')]
                            self.dados = [{'p1': valores[i],
                                         'r1': valores[i+1],
                                         'y1': valores[i+2],
                                         'p2': valores[i+3],
                                         'r2': valores[i+4],
                                         'y2': valores[i+5],
                                         'tempo': valores[i+6]}
                                        for i in range(0, len(valores), 3)]
                    
                    except serial.SerialException as e:
                        print(f"Erro de leitura serial: {e}. Desconectado.")
                        break
            except KeyboardInterrupt:
                print("\nFinalizando e gerando arquivo...")
        receptor.getSerial().close()
        print(f"Arquivo gerado!\nArquivo: {self.nome_arquivo}")

def main():
    print("Testando conexão e Geração de Arquivo!")
    esp32 = Receptor("COM3")
    esp32.ConectarESP32()
    arquivo = SalvarArquivo(qtd_sensores=2)
    arquivo.setHeader()
    input("Pressione enter para iniciar o movimento!")
    arquivo.EscreverArquivo(esp32)
if __name__ == "__main__":
    main()